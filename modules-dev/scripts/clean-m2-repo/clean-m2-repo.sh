#!/usr/bin/env bash
#
# clean-m2-repo.sh
#
# Deletes stale artifact directories from a local Maven repository (~/.m2/repository)
# based on last-access time (atime). This targets artifacts that haven't actually been
# resolved/used recently, rather than guessing based on version numbers.
#
# Requires the filesystem backing ~/.m2 to NOT be mounted with 'noatime'.
# Check with: findmnt -no TARGET,OPTIONS $(df --output=target ~/.m2 | tail -1)
#
# Usage:
#   ./clean-m2-repo.sh [options]
#
# Options:
#   -r, --repo PATH        Path to local repo (default: ~/.m2/repository)
#   -m, --months N         Staleness threshold in months (default: 6)
#   -k, --keep-versions N  Always keep the N highest-numbered versions per artifact,
#                          even if stale (default: 1). Sorted by version string
#                          (e.g. 3.0.10 > 3.0.9), not by download/file time. Set to 0
#                          to disable and judge every version purely on staleness.
#   -y, --yes              Actually delete. Without this, runs in dry-run mode.
#   -v, --verbose          Print each artifact directory considered.
#   --use-mtime            Use modification time instead of access time to judge
#                          staleness. atime is the correct signal for "unused" (Maven
#                          touches atime on resolve, not mtime), but many filesystems/
#                          mounts don't update atime reliably. Use this flag to check
#                          whether atime is the reason nothing is being flagged -- if
#                          --use-mtime finds candidates but the default run doesn't,
#                          your atime tracking is the problem, not your dependencies.
#   -h, --help             Show this help.
#
# Examples:
#   ./clean-m2-repo.sh                      # dry-run, 6 months, default repo
#   ./clean-m2-repo.sh -m 3 -y              # actually delete anything unused for 3+ months
#   ./clean-m2-repo.sh --repo /data/.m2/repository -m 12 -y
#   ./clean-m2-repo.sh --use-mtime -v       # diagnose: is atime the reason nothing shows up?
#
# Cron example (weekly, quiet unless something goes wrong):
#   0 4 * * 1 /path/to/clean-m2-repo.sh -y >> /var/log/m2-cleanup.log 2>&1

set -euo pipefail

REPO="${HOME}/.m2/repository"
#REPO="/home/cacu/.m2/repository/org/glassfish/hk2/hk2-parent"
MONTHS=3
KEEP_VERSIONS=1
DRY_RUN=true
VERBOSE=false
USE_MTIME=false

usage() {
    grep '^#' "$0" | sed -e 's/^#//' -e 's/^ //' | sed -n '2,/^$/p'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--repo) REPO="$2"; shift 2 ;;
        -m|--months) MONTHS="$2"; shift 2 ;;
        -k|--keep-versions) KEEP_VERSIONS="$2"; shift 2 ;;
        -y|--yes) DRY_RUN=false; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --use-mtime) USE_MTIME=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: repository path does not exist: $REPO" >&2
    exit 1
fi

if ! [[ "$MONTHS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --months must be a non-negative integer" >&2
    exit 1
fi

if ! [[ "$KEEP_VERSIONS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --keep-versions must be a non-negative integer" >&2
    exit 1
fi

echo "== Maven local repository cleanup =="
echo "Repo:              $REPO"
echo "Staleness:          ${MONTHS} months"
echo "Keep per artifact:  ${KEEP_VERSIONS} most recent (even if stale)"
echo "Mode:               $([[ "$DRY_RUN" == true ]] && echo 'DRY RUN (no files will be deleted)' || echo 'LIVE (files will be deleted)')"
echo "Time metric:        $([[ "$USE_MTIME" == true ]] && echo 'modification time (mtime) -- diagnostic mode' || echo 'access time (atime)')"
echo

DAYS=$(( MONTHS * 30 ))
TOTAL_FREED=0
TOTAL_DIRS=0

# An "artifact version directory" is a leaf directory directly under a groupId/artifactId
# path that contains actual files (jars, poms, etc). We detect it as: a directory whose
# parent looks like an artifactId dir (i.e. has siblings that are also plain dirs) and
# which itself contains regular files. Simplest robust approach: any directory that
# directly contains at least one *.jar or *.pom file is treated as a "version dir".

mapfile -d '' VERSION_DIRS < <(find "$REPO" -type f \( -name '*.jar' -o -name '*.pom' \) -printf '%h\0' | sort -zu)

echo "Found ${#VERSION_DIRS[@]} artifact-version directories."
echo

# Group version dirs by their parent (the artifactId dir), so we can apply --keep-versions
unset GROUPS 2>/dev/null || true
declare -A ARTIFACT_GROUPS
for d in "${VERSION_DIRS[@]}"; do
    parent="$(dirname "$d")"
    ARTIFACT_GROUPS["$parent"]+="$d"$'\n'
done

for parent in "${!ARTIFACT_GROUPS[@]}"; do
    # versions for this artifact, sorted by version string (highest first).
    # Note: we deliberately sort by the version-directory NAME (e.g. "3.0.5"), not by
    # file mtime. mtime reflects when the file happened to be downloaded to disk, which
    # does not necessarily correlate with version number -- an older version can easily
    # have a newer mtime than a release that came out later but was downloaded earlier.
    # Sorting by version string with `sort -V` gives correct semantic-version ordering
    # (3.0.10 > 3.0.9, 3.0.5 > 3.0.4, etc.) so --keep-versions protects the actual
    # latest version(s), regardless of download history.
    mapfile -t versions < <(
        printf '%s' "${ARTIFACT_GROUPS[$parent]}" | while IFS= read -r vdir; do
            [[ -z "$vdir" ]] && continue
            printf '%s\t%s\n' "$(basename "$vdir")" "$vdir"
        done | sort -t $'\t' -k1,1 -V -r | cut -f2-
    )

    count=0
    for vdir in "${versions[@]}"; do
        count=$((count + 1))

        if [[ $count -le $KEEP_VERSIONS ]]; then
            $VERBOSE && echo "KEEP (highest version, $count/$KEEP_VERSIONS): $vdir"
            continue
        fi

        # Most recently accessed (or modified, in --use-mtime mode) file in this version dir
        if [[ "$USE_MTIME" == true ]]; then
            last_time_epoch=$(find "$vdir" -type f -printf '%T@\n' | sort -rn | head -1)
        else
            last_time_epoch=$(find "$vdir" -type f -printf '%A@\n' | sort -rn | head -1)
        fi
        if [[ -z "$last_time_epoch" ]]; then
            continue
        fi
        last_time_epoch=${last_time_epoch%%.*}
        now_epoch=$(date +%s)
        age_days=$(( (now_epoch - last_time_epoch) / 86400 ))

        if [[ $age_days -ge $DAYS ]]; then
            size=$(du -sh "$vdir" 2>/dev/null | cut -f1)
            size_bytes=$(du -sb "$vdir" 2>/dev/null | cut -f1)
            TOTAL_FREED=$((TOTAL_FREED + size_bytes))
            TOTAL_DIRS=$((TOTAL_DIRS + 1))
            echo "STALE (${age_days}d unused, ${size}): $vdir"
            if [[ "$DRY_RUN" == false ]]; then
                rm -rf "$vdir"
            fi
        else
            $VERBOSE && echo "KEEP (${age_days}d, under threshold): $vdir"
        fi
    done
done

echo
echo "== Summary =="
echo "Stale artifact-version directories: $TOTAL_DIRS"
echo "Space $([[ "$DRY_RUN" == true ]] && echo 'that would be freed' || echo 'freed'): $(numfmt --to=iec-i --suffix=B "$TOTAL_FREED" 2>/dev/null || echo "${TOTAL_FREED} bytes")"

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo "This was a dry run. Re-run with -y/--yes to actually delete."
fi

# Optional: clean up now-empty directories left behind (metadata-only dirs, etc.)
if [[ "$DRY_RUN" == false ]]; then
    find "$REPO" -type d -empty -delete 2>/dev/null || true
fi
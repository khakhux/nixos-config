# clean-m2-repo.sh

A shell script to periodically clean up old/unused dependencies from a local
Maven repository (`~/.m2/repository`), based on when they were actually used —
not just deleting everything but the newest version.

## Why not just "delete all but the latest version"?

Most Maven projects pin a specific dependency version. If you delete every
version except the newest, you'll break local builds for any project that
depends on an older (but still actively used) version, forcing far more
re-downloads than necessary.

Instead, this script uses **file access time (atime)**: Maven touches a
jar/pom's atime every time it's resolved. So "last accessed N months ago"
is a much more accurate signal for "actually unused" than version number
ever could be.

## How it works

1. Finds every directory in the repo that directly contains a `.jar` or
   `.pom` file — that's an "artifact-version directory"
   (e.g. `org/glassfish/hk2/hk2-parent/3.0.5`).
2. Groups those directories by artifact (e.g. all versions of `hk2-parent`).
3. Within each artifact, always **keeps the N highest-numbered versions**
   (`--keep-versions`, default `1`) regardless of staleness — sorted by
   actual version string (`3.0.10 > 3.0.9`), not by download date.
4. For every other version, checks the most recent access time across its
   files. If it's older than the staleness threshold (`--months`, default
   `6`), the directory is flagged and (with `-y`) deleted.

## Requirements

The filesystem backing `~/.m2` must **not** be mounted with `noatime`, or
access times won't be tracked and nothing will ever look "stale". Check with:

```bash
findmnt -no TARGET,OPTIONS $(df --output=target ~/.m2 | tail -1)
```

`relatime` (the modern Linux default) is fine. If you see `noatime`, either
remount without it or use `--use-mtime` as a fallback (see below — less
accurate, since it reflects download time rather than usage).

## Usage

```bash
chmod +x clean-m2-repo.sh

# Dry run with defaults (6 months, keep 1 highest version per artifact)
./clean-m2-repo.sh

# Actually delete
./clean-m2-repo.sh -y

# Custom threshold
./clean-m2-repo.sh -m 3 -y

# Custom repo path
./clean-m2-repo.sh --repo /data/.m2/repository -m 12 -y

# Keep the 2 highest versions per artifact instead of 1
./clean-m2-repo.sh -k 2 -y

# See every decision made, not just deletions
./clean-m2-repo.sh -v
```

### Options

| Flag | Description | Default |
|---|---|---|
| `-r, --repo PATH` | Path to local repo | `~/.m2/repository` |
| `-m, --months N` | Staleness threshold in months | `6` |
| `-k, --keep-versions N` | Always keep the N highest-numbered versions per artifact, even if stale. `0` disables this. | `1` |
| `-y, --yes` | Actually delete. Without it, dry-run only. | off (dry-run) |
| `-v, --verbose` | Print every directory considered, including kept ones | off |
| `--use-mtime` | Use modification time instead of access time (see below) | off |
| `-h, --help` | Show help | |

## Diagnosing "nothing gets flagged"

If a run finds no stale candidates and you expect it to find some:

1. **Check your `.m2` repo isn't simply younger than the threshold.**
   If the repo directory was created 5 months ago, a 6-month threshold will
   never match anything.
2. **Check `--keep-versions` isn't protecting everything.** Most artifacts
   in a typical `.m2` repo only ever have a single cached version — so
   "keep the highest version" ends up keeping nearly everything. Try
   `-k 0 -v` to see the full picture with the safety net off.
3. **Check whether atime is actually being tracked**, using `--use-mtime`
   as a diagnostic:
   ```bash
   ./clean-m2-repo.sh --use-mtime -v -m 6
   ```
   If this finds plenty of candidates but the default (atime) run finds
   none, your filesystem/mount isn't updating atime reliably — see the
   Requirements section above.

## Checking a directory's last-used date manually

To see the most recently accessed file inside a given artifact-version
directory (i.e. the same value the script bases its decision on):

```bash
find /home/cacu/.m2/repository/org/glassfish/hk2/hk2-parent/3.0.5 \
  -type f -printf '%A+ %p\n' | sort -r | head -1
```

To compare atime vs mtime per file (useful if you suspect they disagree,
e.g. because a version was downloaded long after a newer one):

```bash
find /home/cacu/.m2/repository/org/glassfish/hk2/hk2-parent/3.0.5 \
  -type f -printf 'atime=%A+  mtime=%T+  %p\n'
```

Running `stat` or `find` to inspect timestamps is safe — it doesn't read
file contents, so it won't itself update atime.

## Known limitations

- **Version sorting (`sort -V`)** handles standard `x.y.z` version numbers
  correctly (including multi-digit segments like `3.0.10 > 3.0.9`), but may
  not perfectly match Maven's own comparison rules for versions with
  qualifiers like `-SNAPSHOT`, `-RC1`, or `-alpha`. Spot-check with `-v` on
  artifacts using such qualifiers before trusting `-y` broadly.
- **`--use-mtime`** is a diagnostic fallback, not a recommended default: it
  reflects when a file was *downloaded*, not when it was *last used*, so an
  actively-used-but-rarely-redownloaded dependency can look stale under it.

## Automating it (cron)

Run weekly, only logging output if something goes wrong:

```cron
0 4 * * 1 /path/to/clean-m2-repo.sh -y -m 6 >> /var/log/m2-cleanup.log 2>&1
```

Recommendation: run in dry-run mode (no `-y`) for a few weeks first and
review the log before switching to live deletion, especially if you tune
`--months` or `--keep-versions` away from the defaults.

## Check atime of files

`find /home/cacu/.m2/repository/org/glassfish/hk2/hk2-parent/3.0.5 -type f -printf '%A@ %A+ %p\n' | sort -rn | head -5`
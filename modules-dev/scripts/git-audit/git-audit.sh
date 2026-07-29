#!/usr/bin/env bash
#
# git-audit.sh — recursively scan a directory tree for git repositories and report:
#   1) repos that are not clean (uncommitted / untracked changes)
#   2) local branches that have no remote tracking branch
#   3) local branches that have a remote but with unpushed (ahead) commits
#
# Usage:
#   ./git-audit.sh [path] [-f] [-q]
#
#   path   Root directory to scan (default: current directory)
#   -f     Fetch each remote before checking ahead/behind counts (slower, needs network,
#          gives more accurate "unpushed" results since local remote-tracking refs may be stale)
#   -q     Quiet mode: only print repos that have findings, skip clean repos entirely
#
# Exit code: 0 if no issues found, 1 if any issues were found.

set -uo pipefail

ROOT="."
DO_FETCH=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    -f) DO_FETCH=1 ;;
    -q) QUIET=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#//; s/^ //'
      exit 0
      ;;
    *) ROOT="$arg" ;;
  esac
done

if [ ! -d "$ROOT" ]; then
  echo "Error: path '$ROOT' does not exist or is not a directory." >&2
  exit 2
fi

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
  RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; YELLOW=""; GREEN=""; BOLD=""; RESET=""
fi

# Summary trackers
declare -a DIRTY_REPOS=()
declare -a NO_REMOTE_BRANCHES=()
declare -a UNPUSHED_BRANCHES=()
REPO_COUNT=0

echo "Scanning for git repositories under: $(cd "$ROOT" && pwd)"
[ "$DO_FETCH" -eq 1 ] && echo "(fetch mode enabled — will contact remotes)"
echo

# Find all .git directories (repos), skipping nested .git internals
while IFS= read -r -d '' gitdir; do
  repo="$(dirname "$gitdir")"
  REPO_COUNT=$((REPO_COUNT + 1))

  ( # subshell so 'cd' doesn't leak
    cd "$repo" || exit 0

    repo_issues=0
    header_printed=0
    print_header() {
      if [ "$header_printed" -eq 0 ]; then
        echo "${BOLD}== $repo ==${RESET}"
        header_printed=1
      fi
    }

    if [ "$DO_FETCH" -eq 1 ]; then
      git fetch --all --prune --quiet 2>/dev/null
    fi

    # 1) Working tree / index cleanliness
    status_out="$(git status --porcelain 2>/dev/null)"
    if [ -n "$status_out" ]; then
      repo_issues=1
      print_header
      n_changes=$(echo "$status_out" | wc -l | tr -d ' ')
      echo "  ${RED}[DIRTY]${RESET} uncommitted/untracked changes ($n_changes item(s))"
      echo "$repo" >> /tmp/git-audit-dirty.$$
    fi

    # 2 & 3) Branches: no upstream, or ahead of upstream
    while IFS=$'\t' read -r branch upstream; do
      [ -z "$branch" ] && continue
      if [ -z "$upstream" ]; then
        repo_issues=1
        print_header
        echo "  ${YELLOW}[NO REMOTE]${RESET} branch '$branch' has no tracking/remote branch"
        echo "$repo :: $branch" >> /tmp/git-audit-noremote.$$
      else
        counts="$(git rev-list --left-right --count "$branch...$upstream" 2>/dev/null)"
        ahead="$(echo "$counts" | awk '{print $1}')"
        behind="$(echo "$counts" | awk '{print $2}')"
        if [ -n "$ahead" ] && [ "$ahead" -gt 0 ] 2>/dev/null; then
          repo_issues=1
          print_header
          echo "  ${RED}[UNPUSHED]${RESET} branch '$branch' is $ahead commit(s) ahead of '$upstream' (behind: ${behind:-0})"
          echo "$repo :: $branch (ahead $ahead)" >> /tmp/git-audit-unpushed.$$
        fi
      fi
    done < <(git for-each-ref --format='%(refname:short)'$'\t''%(upstream:short)' refs/heads/ 2>/dev/null)

    if [ "$repo_issues" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
      echo "${GREEN}== $repo ==${RESET}  clean, all branches tracked and pushed"
    fi
    [ "$repo_issues" -eq 1 ] && echo
  )
done < <(find "$ROOT" -type d -name ".git" -print0 2>/dev/null)

# Aggregate results written by subshells via temp files (subshell vars don't persist to parent)
[ -f /tmp/git-audit-dirty.$$ ] && mapfile -t DIRTY_REPOS < /tmp/git-audit-dirty.$$ && rm -f /tmp/git-audit-dirty.$$
[ -f /tmp/git-audit-noremote.$$ ] && mapfile -t NO_REMOTE_BRANCHES < /tmp/git-audit-noremote.$$ && rm -f /tmp/git-audit-noremote.$$
[ -f /tmp/git-audit-unpushed.$$ ] && mapfile -t UNPUSHED_BRANCHES < /tmp/git-audit-unpushed.$$ && rm -f /tmp/git-audit-unpushed.$$

echo "${BOLD}========== Summary ==========${RESET}"
echo "Repositories scanned: $REPO_COUNT"
echo "Dirty repos:          ${#DIRTY_REPOS[@]}"
echo "Branches w/o remote:  ${#NO_REMOTE_BRANCHES[@]}"
echo "Unpushed branches:    ${#UNPUSHED_BRANCHES[@]}"

if [ "${#DIRTY_REPOS[@]}" -gt 0 ] || [ "${#NO_REMOTE_BRANCHES[@]}" -gt 0 ] || [ "${#UNPUSHED_BRANCHES[@]}" -gt 0 ]; then
  exit 1
fi
exit 0
#!/usr/bin/env bash
# Move a SINGLE repo's uncommitted work + gitignored files to/from the
# mini PC, alongside (not instead of) the git-based sync scripts.
#
# This exists because sync-gitlab.sh / sync-minipc.sh only ever move
# committed history — by design, so a bad rsync mid-transfer can't
# corrupt .git internals. If you need to hand off work you haven't
# committed yet, use this instead, deliberately, one repo at a time.
#
# Usage:
#   ./handoff.sh push <repo>   # laptop/desktop -> mini PC
#   ./handoff.sh pull <repo>   # mini PC -> laptop/desktop
#
# <repo> can be a bare name ("foo"), a path relative to REPOS_ROOT
# ("team/foo"), or an absolute path.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

usage() {
  echo "Usage: $0 push|pull <repo>" >&2
  exit 1
}

[ $# -eq 2 ] || usage
direction="$1"
repo_arg="$2"

case "$direction" in
  push|pull) ;;
  *) usage ;;
esac

repo="$(resolve_repo "$repo_arg")" || {
  if [ "$repo" = "AMBIGUOUS" ]; then
    echo "ERROR: '$repo_arg' matches more than one repo under $REPOS_ROOT — use a longer path" >&2
  else
    echo "ERROR: no repo matching '$repo_arg' found under $REPOS_ROOT" >&2
  fi
  exit 1
}
rel="$(repo_rel_name "$repo")"
remote_path="$MINIPC_HANDOFF_ROOT/$rel/"
local_path="$repo/"

# Build the rsync exclude args: .git is always excluded (history is git's
# job, not this script's), plus whatever's in HANDOFF_EXCLUDES.
exclude_args=(--exclude ".git")
for e in "${HANDOFF_EXCLUDES[@]}"; do
  exclude_args+=(--exclude "$e")
done

log "=== handoff: $direction $rel ==="

if [ "$direction" = "push" ]; then
  src="$local_path"
  dst="$MINIPC_HOST:$remote_path"
  # Don't clobber uncommitted work already sitting on the mini PC side —
  # if something's there and looks like a git repo with its own dirty
  # state, that's a sign someone (you, on the desktop) is mid-work on
  # that side already; bail rather than guess who wins.
  if ssh "$MINIPC_HOST" "[ -d '$remote_path.git' ]" 2>/dev/null; then
    if ! ssh "$MINIPC_HOST" "cd '$remote_path' && git status --porcelain" 2>/dev/null | grep -q .; then
      : # remote side clean or not a git checkout, safe to proceed
    else
      echo "WARNING: '$remote_path' on the mini PC has uncommitted changes of its own." >&2
      read -r -p "Overwrite it with this machine's copy anyway? [y/N] " confirm
      [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { log "aborted by user"; exit 1; }
    fi
  fi
  ssh "$MINIPC_HOST" "mkdir -p '$remote_path'"
else
  src="$MINIPC_HOST:$remote_path"
  dst="$local_path"
  if ! repo_is_clean "$repo"; then
    echo "WARNING: local '$rel' has uncommitted changes of its own." >&2
    read -r -p "Overwrite it with the mini PC's copy anyway? [y/N] " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { log "aborted by user"; exit 1; }
  fi
fi

rsync -az --delete "${exclude_args[@]}" "$src" "$dst" 2>&1 | sed 's/^/   /'

log "=== handoff: $direction $rel done ==="
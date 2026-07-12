#!/usr/bin/env bash
# Run on the fresh desktop before working. Clones any repo that exists on
# the mini PC's bare store but not (yet) locally under REPOS_ROOT.
# Safe to run every time — existing repos are left untouched.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

log "=== bootstrap-desktop: start ==="
mkdir -p "$REPOS_ROOT"

bare_list="$(ssh_shared "$MINIPC_HOST" "find '$MINIPC_BARE_ROOT' -type d -name '*.git'")"

while IFS= read -r bare_path; do
  [ -z "$bare_path" ] && continue
  rel="${bare_path#"$MINIPC_BARE_ROOT"/}"
  rel="${rel%.git}"

  if repo_is_minipc_ignored "$rel"; then
    continue
  fi

  local_path="$REPOS_ROOT/$rel"

  if [ -d "$local_path/.git" ]; then
    continue
  fi

  log "-> cloning $rel"
  mkdir -p "$(dirname "$local_path")"
  git clone --origin "$MINIPC_REMOTE" "$MINIPC_HOST:$bare_path" "$local_path" 2>&1 | sed 's/^/   /'
done <<<"$bare_list"

log "=== bootstrap-desktop: done ==="

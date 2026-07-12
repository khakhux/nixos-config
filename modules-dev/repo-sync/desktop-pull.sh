#!/usr/bin/env bash
# Run on the desktop at the START of a session (workplace 2, no laptop).
# Clones anything new, then fetches/fast-forwards existing repos.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

"$DIR/bootstrap-desktop.sh"

log "=== desktop-pull: start ==="

mapfile -t repos < <(find_repos_minipc)

for repo in "${repos[@]}"; do
  name="$(basename "$repo")"
  rel="$(repo_rel_name "$repo")"
  log "-> $name"

  if ! remote_exists "$repo" "$MINIPC_REMOTE"; then
    log "   no '$MINIPC_REMOTE' remote, skipping"
    continue
  fi

  try_ff_pull "$repo" "$MINIPC_REMOTE" || log "   WARNING: fetch/merge step failed for $name, see above"
  sync_worktree_snapshot_pull "$repo" "$rel" laptop \
    || log "   WARNING: worktree snapshot restore failed for $name"
done

log "=== desktop-pull: done ==="

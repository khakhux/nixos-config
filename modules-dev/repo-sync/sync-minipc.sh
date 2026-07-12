#!/usr/bin/env bash
# Run on the laptop while at workplace 2 (mini PC reachable).
# Auto-creates a bare mirror on the mini PC for any new repo, pushes your
# local work there, and fetches/fast-forwards anything the desktop pushed
# while you were away.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

log "=== sync-minipc: start (laptop) ==="

mapfile -t repos < <(find_repos_minipc)

for repo in "${repos[@]}"; do
  name="$(basename "$repo")"
  rel="$(repo_rel_name "$repo")"
  log "-> $name ($rel)"

  ensure_bare_on_minipc "$rel" || log "   WARNING: could not ensure bare repo on mini PC"

  if ! remote_exists "$repo" "$MINIPC_REMOTE"; then
    log "   adding '$MINIPC_REMOTE' remote"
    git -C "$repo" remote add "$MINIPC_REMOTE" "$MINIPC_HOST:$MINIPC_BARE_ROOT/$rel.git"
  fi

  if ! repo_is_clean "$repo"; then
    log "   uncommitted changes present; pushing commits and uploading snapshot"
  fi

  push_all_refs "$repo" "$MINIPC_REMOTE" \
    || log "   WARNING: push failed (diverged on mini PC?), see above"

  sync_worktree_snapshot_push "$repo" "$rel" laptop \
    || log "   WARNING: worktree snapshot upload failed for $name"

  try_ff_pull "$repo" "$MINIPC_REMOTE" || log "   WARNING: fetch/merge step failed for $name, see above"
  sync_worktree_snapshot_pull "$repo" "$rel" desktop \
    || log "   WARNING: worktree snapshot restore failed for $name"
  sync_live_worktree_to_minipc "$repo" "$rel" \
    || log "   WARNING: live worktree mirror failed for $name"
done

log "=== sync-minipc: done (laptop) ==="

#!/usr/bin/env bash
# Run on the desktop at the END of a session (workplace 2, no laptop),
# before it gets rebuilt/reset. Pushes everything back to the mini PC.
# This is the important one — don't skip it.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

log "=== desktop-push: start ==="

mapfile -t repos < <(find_repos_minipc)

for repo in "${repos[@]}"; do
  name="$(basename "$repo")"
  rel="$(repo_rel_name "$repo")"
  log "-> $name"

  if ! remote_exists "$repo" "$MINIPC_REMOTE"; then
    log "   no '$MINIPC_REMOTE' remote, skipping"
    continue
  fi

  if ! repo_is_clean "$repo"; then
    log "   uncommitted changes present; pushing commits and uploading snapshot"
  fi

  push_all_refs "$repo" "$MINIPC_REMOTE" \
    || log "   WARNING: push failed (diverged on mini PC?), see above"

  sync_worktree_snapshot_push "$repo" "$rel" desktop \
    || log "   WARNING: worktree snapshot upload failed for $name"
  sync_live_worktree_to_minipc "$repo" "$rel" \
    || log "   WARNING: live worktree mirror failed for $name"
done

log "=== desktop-push: done ==="

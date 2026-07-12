#!/usr/bin/env bash
# Run on the laptop while at workplace 1 (GitLab reachable).
# Pushes your local work to GitLab, then fetches everything else.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

log "=== sync-gitlab: start ==="

mapfile -t repos < <(find_repos)

for repo in "${repos[@]}"; do
  name="$(basename "$repo")"
  log "-> $name"

  if ! remote_exists "$repo" "$GITLAB_REMOTE"; then
    log "   no '$GITLAB_REMOTE' remote configured, skipping"
    continue
  fi

  branch="$(current_branch "$repo")"

  case "$GITLAB_PUSH_MODE" in
    none)
      : # you push to GitLab yourself — this script only fetches
      ;;
    all)
      if [ -n "$branch" ]; then
        if ! repo_is_clean "$repo"; then
          log "   uncommitted changes present, not pushing (commit or stash first)"
        else
          push_all_refs "$repo" "$GITLAB_REMOTE" \
            || log "   WARNING: push --all failed (diverged branch?), see above"
        fi
      fi
      ;;
    current|*)
      if [ -n "$branch" ]; then
        if ! repo_is_clean "$repo"; then
          log "   uncommitted changes present, not pushing (commit or stash first)"
        else
          push_branch_and_tags "$repo" "$GITLAB_REMOTE" "$branch" \
            || log "   WARNING: push failed (diverged branch?), see above"
        fi
      fi
      ;;
  esac

  git -C "$repo" fetch "$GITLAB_REMOTE" --prune --tags 2>&1 | sed 's/^/   /'
done

log "=== sync-gitlab: done ==="

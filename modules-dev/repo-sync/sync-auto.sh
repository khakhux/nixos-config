#!/usr/bin/env bash
# Run on the laptop, anywhere. Detects whether GitLab or the mini PC is
# reachable and runs the matching sync. If neither is reachable (offsite,
# or VPN down and away from both sites), it does nothing.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
source "$DIR/lib.sh"

if host_reachable_tcp "$GITLAB_HOST" "$GITLAB_HOST_PORT"; then
  log "GitLab reachable -> running sync-gitlab.sh"
  exec "$DIR/sync-gitlab.sh"
elif minipc_reachable; then
  log "mini PC reachable -> running sync-minipc.sh"
  exec "$DIR/sync-minipc.sh"
else
  log "Neither GitLab nor mini PC reachable — offline, nothing to sync"
fi

#!/usr/bin/env bash
# repo-sync shared functions. Sourced by other scripts; not run directly.

# find's -type d test doesn't reliably descend through a symlinked
# REPOS_ROOT on every system (this bit us on WSL2). Resolve it once here
# so config.sh can keep using the friendly "/repos" symlink everywhere,
# and every function below works off the real path.
if [ -e "$REPOS_ROOT" ]; then
  REPOS_ROOT="$(realpath "$REPOS_ROOT")"
else
  echo "ERROR: REPOS_ROOT '$REPOS_ROOT' does not exist or is a dangling symlink" >&2
  exit 1
fi

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "[$ts] $*" >>"$LOG_FILE" 2>/dev/null || true
}

MINIPC_SSH_SOCKET_DIR="${XDG_RUNTIME_DIR:-/tmp}/repo-sync-ssh-${UID}"
MINIPC_SSH_CONTROL_PATH="$MINIPC_SSH_SOCKET_DIR/%C"
MINIPC_SSH_OPTS=(
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="$MINIPC_SSH_CONTROL_PATH"
)
: "${MINIPC_SNAPSHOT_ROOT:=$MINIPC_BARE_ROOT/.repo-sync-worktrees}"
: "${MINIPC_WORKTREE_ROOT:=${MINIPC_BARE_ROOT%/}-working}"

init_shared_ssh() {
  mkdir -p "$MINIPC_SSH_SOCKET_DIR"
  chmod 700 "$MINIPC_SSH_SOCKET_DIR" 2>/dev/null || true

  export GIT_SSH_COMMAND
  GIT_SSH_COMMAND="ssh -o ControlMaster=auto -o ControlPersist=10m -o ControlPath=$MINIPC_SSH_CONTROL_PATH"
}

ssh_shared() {
  ssh "${MINIPC_SSH_OPTS[@]}" "$@"
}

shell_quote() {
  printf '%q' "$1"
}

init_shared_ssh

# Print the absolute path of every repo's working directory under REPOS_ROOT.
find_repos_raw() {
  find "$REPOS_ROOT" -maxdepth "$FIND_MAXDEPTH" -type d -name ".git" -printf '%h\n' 2>/dev/null | sort
}

repo_is_ignored() {
  local rel="$1"
  local ignored

  for ignored in "${IGNORE_DIRS[@]:-}"; do
    if [ "$rel" = "$ignored" ] || [[ "$rel" == "$ignored/"* ]]; then
      return 0
    fi
  done

  return 1
}

repo_is_minipc_ignored() {
  local rel="$1"
  local top_level="${rel%%/*}"
  local ignored

  if repo_is_ignored "$rel"; then
    return 0
  fi

  for ignored in "${IGNORE_DIRS_MINIPC[@]:-}"; do
    if [ "$top_level" = "$ignored" ]; then
      return 0
    fi
  done

  return 1
}

find_repos_minipc() {
  local repo rel

  while IFS= read -r repo; do
    rel="$(repo_rel_name "$repo")"
    if repo_is_minipc_ignored "$rel"; then
      continue
    fi
    printf '%s\n' "$repo"
  done < <(find_repos)
}

find_repos() {
  local repo rel

  while IFS= read -r repo; do
    rel="$(repo_rel_name "$repo")"
    if repo_is_ignored "$rel"; then
      continue
    fi
    printf '%s\n' "$repo"
  done < <(find_repos_raw)
}

# Path of a repo relative to REPOS_ROOT, e.g. /repos/team/foo -> team/foo.
# Used as the matching path for the bare mirror on the mini PC.
repo_rel_name() {
  realpath --relative-to="$REPOS_ROOT" "$1"
}

remote_exists() {
  git -C "$1" remote get-url "$2" >/dev/null 2>&1
}

repo_is_clean() {
  [ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ]
}

current_branch() {
  git -C "$1" symbolic-ref --quiet --short HEAD || true
}

push_all_refs() {
  local repo="$1" remote="$2"

  git -C "$repo" push "$remote" --all 2>&1 | sed 's/^/   /' || return 1
  git -C "$repo" push "$remote" --tags 2>&1 | sed 's/^/   /'
}

push_branch_and_tags() {
  local repo="$1" remote="$2" branch="$3"

  git -C "$repo" push "$remote" "$branch" 2>&1 | sed 's/^/   /' || return 1
  git -C "$repo" push "$remote" --tags 2>&1 | sed 's/^/   /'
}

current_commit() {
  git -C "$1" rev-parse --verify HEAD 2>/dev/null || printf '%s\n' "UNBORN"
}

snapshot_remote_archive_path() {
  printf '%s/%s/%s.tar.gz\n' "$MINIPC_SNAPSHOT_ROOT" "$1" "$2"
}

snapshot_remote_meta_path() {
  printf '%s/%s/%s.meta\n' "$MINIPC_SNAPSHOT_ROOT" "$1" "$2"
}

snapshot_local_marker_path() {
  printf '%s/.git/repo-sync/%s.last\n' "$1" "$2"
}

snapshot_meta_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }'
}

clear_worktree_snapshot() {
  local rel="$1" role="$2"
  local archive_path meta_path

  archive_path="$(snapshot_remote_archive_path "$role" "$rel")"
  meta_path="$(snapshot_remote_meta_path "$role" "$rel")"

  ssh_shared "$MINIPC_HOST" \
    "rm -f $(shell_quote "$archive_path") $(shell_quote "$meta_path")" >/dev/null 2>&1 || true
}

upload_worktree_snapshot() {
  local repo="$1" rel="$2" role="$3"
  local archive_path meta_path archive_dir
  local tmp_archive tmp_meta snapshot_id head_commit created_at

  archive_path="$(snapshot_remote_archive_path "$role" "$rel")"
  meta_path="$(snapshot_remote_meta_path "$role" "$rel")"
  archive_dir="$(dirname "$archive_path")"
  tmp_archive="$(mktemp)"
  tmp_meta="$(mktemp)"

  tar -C "$repo" --exclude=.git -czf "$tmp_archive" .
  snapshot_id="$(sha256sum "$tmp_archive" | awk '{print $1}')"
  head_commit="$(current_commit "$repo")"
  created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  cat >"$tmp_meta" <<EOF
snapshot_id=$snapshot_id
head_commit=$head_commit
created_at=$created_at
role=$role
EOF

  ssh_shared "$MINIPC_HOST" "mkdir -p $(shell_quote "$archive_dir")"
  cat "$tmp_archive" | ssh_shared "$MINIPC_HOST" "cat > $(shell_quote "$archive_path")"
  cat "$tmp_meta" | ssh_shared "$MINIPC_HOST" "cat > $(shell_quote "$meta_path")"

  rm -f "$tmp_archive" "$tmp_meta"
}

sync_worktree_snapshot_push() {
  local repo="$1" rel="$2" role="$3"

  if repo_is_clean "$repo"; then
    clear_worktree_snapshot "$rel" "$role"
    return 0
  fi

  log "   uploading uncommitted worktree snapshot ($role)"
  upload_worktree_snapshot "$repo" "$rel" "$role"
}

restore_worktree_snapshot() {
  local repo="$1" rel="$2" role="$3"
  local archive_path meta_path meta snapshot_id head_commit created_at marker_path applied_token
  local current_head tmp_archive tmp_dir

  archive_path="$(snapshot_remote_archive_path "$role" "$rel")"
  meta_path="$(snapshot_remote_meta_path "$role" "$rel")"

  if ! meta="$(ssh_shared "$MINIPC_HOST" "cat $(shell_quote "$meta_path")" 2>/dev/null)"; then
    return 0
  fi

  snapshot_id="$(printf '%s\n' "$meta" | snapshot_meta_value snapshot_id)"
  head_commit="$(printf '%s\n' "$meta" | snapshot_meta_value head_commit)"
  created_at="$(printf '%s\n' "$meta" | snapshot_meta_value created_at)"
  [ -z "$snapshot_id" ] && return 0
  applied_token="$snapshot_id:${created_at:-unknown}"

  marker_path="$(snapshot_local_marker_path "$repo" "$role")"
  if [ -f "$marker_path" ] && [ "$(cat "$marker_path")" = "$applied_token" ]; then
    return 0
  fi

  if ! repo_is_clean "$repo"; then
    log "   local repo is dirty, not restoring $role snapshot"
    return 0
  fi

  current_head="$(current_commit "$repo")"
  if [ "$current_head" != "$head_commit" ]; then
    log "   $role snapshot is based on $head_commit, local HEAD is $current_head; skipping restore"
    return 0
  fi

  tmp_archive="$(mktemp)"
  tmp_dir="$(mktemp -d)"

  if ! ssh_shared "$MINIPC_HOST" "cat $(shell_quote "$archive_path")" >"$tmp_archive" 2>/dev/null; then
    rm -f "$tmp_archive"
    rmdir "$tmp_dir" 2>/dev/null || true
    return 0
  fi

  tar -xzf "$tmp_archive" -C "$tmp_dir"
  find "$repo" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +
  cp -a "$tmp_dir"/. "$repo"/

  mkdir -p "$(dirname "$marker_path")"
  printf '%s\n' "$applied_token" >"$marker_path"
  log "   restored uncommitted worktree snapshot from $role"

  rm -f "$tmp_archive"
  rm -rf "$tmp_dir"
}

sync_worktree_snapshot_pull() {
  restore_worktree_snapshot "$1" "$2" "$3"
}

sync_live_worktree_to_minipc() {
  local repo="$1" rel="$2"
  local remote_path remote_parent tmp_path

  remote_path="$MINIPC_WORKTREE_ROOT/$rel"
  remote_parent="$(dirname "$remote_path")"
  tmp_path="${remote_path}.repo-sync-tmp-$$"

  if ! ssh_shared "$MINIPC_HOST" \
    "mkdir -p $(shell_quote "$remote_parent") && rm -rf $(shell_quote "$tmp_path") && mkdir -p $(shell_quote "$tmp_path")"; then
    return 1
  fi

  if ! tar -C "$repo" --exclude=.git -czf - . | \
    ssh_shared "$MINIPC_HOST" "tar -xzf - -C $(shell_quote "$tmp_path")"; then
    ssh_shared "$MINIPC_HOST" "rm -rf $(shell_quote "$tmp_path")" >/dev/null 2>&1 || true
    return 1
  fi

  ssh_shared "$MINIPC_HOST" \
    "rm -rf $(shell_quote "$remote_path") && mv $(shell_quote "$tmp_path") $(shell_quote "$remote_path")"
}

# Create the bare mirror on the mini PC for this repo if it doesn't exist yet.
# Safe to call every time — it's a no-op once the bare repo is there.
ensure_bare_on_minipc() {
  local rel="$1"
  ssh_shared "$MINIPC_HOST" \
    "mkdir -p \"\$(dirname '$MINIPC_BARE_ROOT/$rel.git')\" && \
     [ -d '$MINIPC_BARE_ROOT/$rel.git' ] || git init --quiet --bare '$MINIPC_BARE_ROOT/$rel.git'"
}

# Fetch from $2 (remote name) and fast-forward the current branch only if
# it's clean and a fast-forward is actually possible. Never force, never
# rewrites history — if it can't fast-forward it just says so and moves on.
try_ff_pull() {
  local repo="$1" remote="$2"
  local branch
  branch="$(current_branch "$repo")"
  [ -z "$branch" ] && return 0

  if ! git -C "$repo" fetch "$remote" --prune --tags 2>&1 | sed 's/^/   /'; then
    log "   fetch from $remote failed"
    return 1
  fi

  if ! git -C "$repo" rev-parse --verify --quiet "$remote/$branch" >/dev/null; then
    return 0
  fi

  if ! repo_is_clean "$repo"; then
    log "   uncommitted changes present, not merging $remote/$branch"
    return 0
  fi

  if git -C "$repo" merge-base --is-ancestor "$remote/$branch" HEAD; then
    return 0 # already up to date
  fi

  if git -C "$repo" merge-base --is-ancestor HEAD "$remote/$branch"; then
    git -C "$repo" merge --ff-only "$remote/$branch" 2>&1 | sed 's/^/   /'
  else
    log "   NOTE: '$branch' has diverged from $remote/$branch — merge/rebase manually"
  fi
}

host_reachable_tcp() {
  local host="$1" port="$2"
  timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
}

minipc_reachable() {
  ssh_shared -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "$MINIPC_HOST" true 2>/dev/null
}

# Resolve a repo argument (name or path) to its absolute local path under
# REPOS_ROOT. Accepts either a relative path ("team/foo"), a bare name
# ("foo", matched by basename if unambiguous), or an absolute path.
resolve_repo() {
  local arg="$1" match
  if [ -d "$arg/.git" ]; then
    realpath "$arg"
    return 0
  fi
  if [ -d "$REPOS_ROOT/$arg/.git" ]; then
    realpath "$REPOS_ROOT/$arg"
    return 0
  fi
  match="$(find_repos | while IFS= read -r r; do
    [ "$(basename "$r")" = "$arg" ] && echo "$r"
  done)"
  if [ -z "$match" ]; then
    return 1
  fi
  if [ "$(wc -l <<<"$match")" -gt 1 ]; then
    echo "AMBIGUOUS" # caller checks for this
    return 1
  fi
  echo "$match"
}
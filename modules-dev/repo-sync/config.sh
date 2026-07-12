#!/usr/bin/env bash
# repo-sync configuration — edit these for your environment.
# Sourced by every other script; not meant to be run directly.

# Root directory (symlink is fine) where all your working repos live.
REPOS_ROOT="/repos"

# How deep under REPOS_ROOT to look for ".git" dirs. 2 is enough for
# /repos/<name>/.git ; bump it if you nest repos in subfolders.
FIND_MAXDEPTH=8

# Name of the git remote pointing at GitLab in your existing repos.
# If your repos already use "origin" for GitLab, set this to "origin".
GITLAB_REMOTE="origin"

# Hostname/IP used only to test "am I on the GitLab network right now".
# Use whatever resolves from the laptop when at workplace 1, e.g. the
# GitLab server's hostname or the reverse proxy in front of it.
GITLAB_HOST="gitlab.central.sepg.minhac.age"
GITLAB_HOST_PORT="443"

# Name of the git remote pointing at the mini PC's bare mirror store.
MINIPC_REMOTE="mininas"

# SSH host alias for the mini PC. Define this in ~/.ssh/config on both
# the laptop (WSL2) and the desktop, e.g.:
#   Host mininas
#       HostName 192.168.1.50
#       User you
#       IdentityFile ~/.ssh/id_ed25519
MINIPC_HOST="mininas-git-syncs"

# Where bare mirror repos live on the mini PC.
MINIPC_BARE_ROOT="/nvme2/backups/curro/repos"

# Where plain working-tree copies live on the mini PC. These contain the
# actual files from each repo, separate from the bare .git mirrors used
# for git transport between machines.
MINIPC_WORKTREE_ROOT="/nvme2/backups/curro/repos-working"

# Push mode for the GitLab sync:
#   "none"    - never push to GitLab automatically; sync-gitlab.sh only
#               fetches. Push yourself with `git push` when you're ready.
#   "current" - push only the checked-out branch.
#   "all"     - push every local branch.
GITLAB_PUSH_MODE="none"

# Where to append a running log of what each script did.
LOG_FILE="${HOME}/.local/state/repo-sync/sync.log"

# Repos to skip, given as paths relative to REPOS_ROOT
# (e.g. "team/legacy-thing", "scratch/old-experiment").
IGNORE_DIRS=("sgad" "sgife2" "div1" "kubo")

# Top-level directories under REPOS_ROOT to skip only when syncing to the
# mini PC (e.g. repos you don't want mirrored there for space/sensitivity
# reasons, even though they're still synced with GitLab normally).
IGNORE_DIRS_MINIPC=("sgad" "sgife2" "div1" "autorizacion")

# Where handoff.sh rsyncs a repo's *working tree* to/from on the mini PC —
# a plain directory tree (not a bare repo), separate from
# MINIPC_BARE_ROOT, since it holds uncommitted files and gitignored files
# too, not git history.
MINIPC_HANDOFF_ROOT="/backups/curro/handoff"
 
# Extra rsync excludes for handoff.sh, on top of ".git" which is always
# excluded (git history is synced separately, via the gitlab/minipc
# remotes, not by copying .git). Add build output, secrets you don't want
# leaving the machine, etc.
HANDOFF_EXCLUDES=("node_modules" ".env")
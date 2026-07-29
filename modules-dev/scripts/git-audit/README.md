# git-audit

A single bash script that recursively scans a directory tree for git repositories and
reports repos that need attention before you walk away from your machine, wipe a
drive, or archive a folder.

It flags three things per repository:

1. **Dirty repos** — uncommitted or untracked changes in the working tree/index.
2. **Branches with no remote** — local branches that were never linked to an
   upstream tracking branch (so `git push` alone won't know where to go).
3. **Branches with unpushed commits** — local branches that do have an upstream,
   but are ahead of it (commits that exist only on your machine).

## Requirements

- bash
- git

No other dependencies.

## Installation

```bash
chmod +x git-audit.sh
```

Optionally move it somewhere on your `$PATH`:

```bash
mv git-audit.sh ~/bin/git-audit
```

## Usage

```bash
./git-audit.sh [path] [-f] [-q]
```

| Argument | Description |
|---|---|
| `path` | Root directory to scan recursively. Defaults to the current directory. |
| `-f` | Fetch each repo's remotes before checking (`git fetch --all --prune`). Slower and requires network access, but gives accurate ahead/behind counts. Without it, results rely on your locally cached remote-tracking refs, which can be stale. |
| `-q` | Quiet mode — only print repos that have findings; clean repos are omitted entirely. |
| `-h`, `--help` | Print usage help. |

### Examples

```bash
# Scan everything under ~/code
./git-audit.sh ~/code

# Scan and fetch first, for accurate unpushed-commit detection
./git-audit.sh ~/code -f

# Only show problem repos, ignore clean ones
./git-audit.sh ~/code -q

# Combine flags, use in a script / cron job
./git-audit.sh ~/code -f -q && echo "all clean" || echo "issues found"
```

## Sample output

```
Scanning for git repositories under: /home/me/code

== /home/me/code/service-a ==
  [DIRTY] uncommitted/untracked changes (3 item(s))
  [NO REMOTE] branch 'user/main' has no tracking/remote branch

== /home/me/code/service-b ==  clean, all branches tracked and pushed

== /home/me/code/service-c ==
  [UNPUSHED] branch 'feature-x' is 2 commit(s) ahead of 'origin/feature-x' (behind: 0)

========== Summary ==========
Repositories scanned: 3
Dirty repos:          1
Branches w/o remote:  1
Unpushed branches:    1
```

## Exit codes

- `0` — no issues found across any scanned repo.
- `1` — at least one issue (dirty repo, untracked branch, or unpushed commits) was found.
- `2` — the given path does not exist.

Non-zero exit codes make this easy to wire into CI, pre-shutdown checks, or a cron
job that emails you a report.

## How the checks work

- **Dirty**: `git status --porcelain` — non-empty output means something is
  uncommitted or untracked.
- **No remote**: `git for-each-ref --format='%(refname:short)\t%(upstream:short)'
  refs/heads/` — an empty upstream field means that branch has no tracking branch.
  This is a different thing from `git remote -v`: a repo can have a remote
  configured while individual branches were never linked to it (e.g. created
  locally and never pushed with `-u`, or checked out via a tool that names
  branches `<user>/<branch>` without wiring up tracking).
- **Unpushed**: for branches that do have an upstream, `git rev-list --left-right
  --count <branch>...<upstream>` — the left count is commits that exist locally
  but not on the remote (ahead / unpushed); the right count is commits on the
  remote not yet pulled locally (behind).

## Notes / limitations

- Only local branches are checked (`refs/heads/`), not remote-tracking refs or tags.
- Without `-f`, ahead/behind and "no remote" results reflect your last-known state
  of the remote, not necessarily what's on GitHub/GitLab/etc. right now.
- Submodules are treated as independent repos if they contain their own `.git`
  entry, so they'll show up as separate scan results.
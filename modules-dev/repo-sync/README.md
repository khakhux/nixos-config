# repo-sync

Keeps `/repos` reasonably up to date across laptop, mini PC, and the
workplace-2 desktop, without USB drives — by treating the mini PC as a
small git server instead of an rsync target.

## Topology

```
GitLab ──(workplace 1)── Laptop ──(workplace 2)── Mini PC ── Desktop
```

The laptop is the only machine that ever reaches both GitLab and the mini
PC (never at the same time). It acts as the courier, carrying *commits*
(not folder snapshots) between the two. The mini PC hosts a bare git
mirror for every repo; both the laptop and the desktop push/fetch to it
like any other remote.

Each repo ends up with two remotes:
- `gitlab` — your existing GitLab remote (rename to match `GITLAB_REMOTE`
  in `config.sh`, or just point that variable at `origin`).
- `minipc` — added automatically the first time you sync at workplace 2,
  pointing at a bare mirror on the mini PC that's also created
  automatically if missing.

On the mini PC, each repo can exist in two forms:
- a bare mirror under `MINIPC_BARE_ROOT` for Git transport
- a plain working-tree copy under `MINIPC_WORKTREE_ROOT` with the actual files

## One-time setup

1. Edit `config.sh` — paths, hostnames, remote names.
2. Make sure `~/.ssh/config` on the laptop and desktop has a `minipc`
   host entry with the right IP/user/key for the workplace-2 network:
   ```
   Host minipc
       HostName 192.168.1.50
       User you
       IdentityFile ~/.ssh/id_ed25519
   ```
3. On the mini PC: make sure `sshd` is running and `MINIPC_BARE_ROOT`
   (default `/srv/git-mirror`) exists and is writable by that user.
   Nothing else needs to run on the mini PC — the scripts create bare
   repos there over SSH as needed.
4. `chmod +x *.sh`

## Daily workflow

**Workplace 1, laptop:**
```
./sync-gitlab.sh
```
By default (`GITLAB_PUSH_MODE=none`) this only fetches from GitLab — it
never pushes for you, so `git push` stays a manual, deliberate action.
Set `GITLAB_PUSH_MODE=current` or `all` in `config.sh` if you'd rather it
push your checked-out branch (or every local branch) automatically.

**Workplace 2, laptop present:**
```
./sync-minipc.sh
```
Pushes local work to the mini PC (creating mirrors for new repos
automatically), uploads any uncommitted worktree as a separate snapshot,
refreshes the mini PC working-tree copy, and fast-forwards anything the
desktop pushed while you were away.

**Workplace 2, laptop absent (fresh desktop):**
```
./desktop-pull.sh   # start of session — clones new repos, pulls updates
# ... work ...
./desktop-push.sh   # end of session — MUST run before the desktop resets
```
`desktop-pull.sh` also restores the laptop's latest uncommitted worktree
snapshot when the repo is on the same commit, and `desktop-push.sh`
uploads the desktop's uncommitted work the same way while refreshing the
mini PC working-tree copy.

**Don't want to remember which script to run on the laptop?**
```
./sync-auto.sh
```
Checks which network you're on and runs `sync-gitlab.sh` or
`sync-minipc.sh` accordingly. Does nothing if neither is reachable
(offsite, or VPN down and away from both sites) — that's expected, work
locally and sync later.

## What changed from the rsync plan, and why

- **Git remotes instead of rsync of working trees.** rsync-ing `.git/`
  directly risks clobbering another machine's uncommitted state and has
  no notion of "these histories diverged" — it just overwrites. Git
  fetch/push already solves exactly this problem.
- **USB is gone.** Desktop work reaches GitLab automatically: desktop →
  mini PC (on push) → laptop (next time it's at workplace 2) → GitLab
  (next time the laptop is at workplace 1). No manual carrying required.
- **New repos are handled automatically**, per your requirement — repo
  discovery is a `find` for `.git` dirs under `REPOS_ROOT`, and the mini
  PC side auto-creates a matching bare repo on first push. Nothing to
  maintain in a list.
- **Nothing force-pushes or rewrites history.** Every merge is
  fast-forward-only; if a branch has genuinely diverged (e.g. you edited
  the same branch on both the laptop and the desktop before syncing), the
  script logs a note and leaves it for you to merge by hand rather than
  guessing.
- **Uncommitted work is relayed separately from commits.** Dirty repos are
  archived to the mini PC as worktree snapshots and only restored onto
  the other machine when that repo is clean and on the same base commit,
  so branch history stays untouched.

## Remaining limitation (topology, not scripting)

If the laptop goes workplace 1 → offsite → workplace 1 → ... and never
revisits workplace 2, anything pushed from the desktop sits on the mini
PC until the laptop does visit workplace 2. There's no way around this
without giving the mini PC direct GitLab access or relying on VPN — but
unlike the original plan, nothing is lost, it's just delayed, and no USB
step is required to eventually deliver it.

## Notes

- `GITLAB_PUSH_MODE=none` (default) never pushes to GitLab automatically —
  `sync-gitlab.sh` only fetches, and you push manually whenever you're
  ready. Set to `current` to auto-push just the checked-out branch, or
  `all` to auto-push every local branch. Note this only affects the
  `gitlab` remote; pushes to the mini PC (`sync-minipc.sh`,
  `desktop-push.sh`) are unaffected and still happen automatically, since
  that's just a private relay, not a shared server.
- All scripts log to `~/.local/state/repo-sync/sync.log` in addition to
  stdout, so you can check what happened after the fact (handy for
  `sync-auto.sh` if you want to cron/hook it).
- Worktree snapshots live under `$MINIPC_SNAPSHOT_ROOT` on the mini PC
  (default: `$MINIPC_BARE_ROOT/.repo-sync-worktrees`). They are cleared
  automatically the next time that machine syncs the repo in a clean
  state.
- Plain working files live under `$MINIPC_WORKTREE_ROOT` on the mini PC
  and are rewritten from the syncing machine's current worktree on each
  successful workplace-2 sync.




## Handing off uncommitted work

The git-based scripts above only ever move *committed* history — by
design, so a bad transfer can't corrupt `.git` internals. If you need to
carry over work you haven't committed yet (or files you've gitignored on
purpose, like local `.env` config), use `handoff.sh` instead, for exactly
one repo, one direction, at a time:

```
./handoff.sh push <repo>   # this machine -> mini PC
./handoff.sh pull <repo>   # mini PC -> this machine
```

`<repo>` can be a bare name (`foo`), a path relative to `REPOS_ROOT`
(`team/foo`), or an absolute path.

This is plain `rsync`, always excluding `.git` (history is the git
scripts' job) plus anything in `HANDOFF_EXCLUDES` in `config.sh`. It's
deliberately a manual, one-off action rather than something that runs
automatically for every repo — unlike `sync-minipc.sh`, there's no safe
way to guess the right direction across three machines for uncommitted
work, so you tell it explicitly each time. If the destination already has
uncommitted changes of its own, it warns and asks before overwriting.



- `GITLAB_PUSH_MODE=none` (default) never pushes to GitLab automatically —
  `sync-gitlab.sh` only fetches, and you push manually whenever you're
  ready. Set to `current` to auto-push just the checked-out branch, or
  `all` to auto-push every local branch. Note this only affects the
  `gitlab` remote; pushes to the mini PC (`sync-minipc.sh`,
  `desktop-push.sh`) are unaffected and still happen automatically, since
  that's just a private relay, not a shared server.
- All scripts log to `~/.local/state/repo-sync/sync.log` in addition to
  stdout, so you can check what happened after the fact (handy for
  `sync-auto.sh` if you want to cron/hook it).
- `desktop-push.sh` exits non-zero if it finds uncommitted changes it
  couldn't push — wire that into whatever shuts the desktop down (a
  systemd unit, a keybinding, etc.) so you don't accidentally reset a
  machine with unpushed work still on it.
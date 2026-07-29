# AGENTS.md

Guidance for AI coding agents (and future contributors) working in this
repository. Read this before modifying `git-audit.sh`.

## Project overview

This repo contains a single self-contained bash script, `git-audit.sh`, that
recursively scans a directory tree for git repositories and reports:

- repos with uncommitted/untracked changes ("dirty")
- local branches with no upstream tracking branch ("no remote")
- local branches ahead of their upstream ("unpushed")

There is no build step, no package manager, and no runtime dependency beyond
`bash` and `git`. Keep it that way — this tool's value is that it runs
anywhere with zero setup.

## Files

| File | Purpose |
|---|---|
| `git-audit.sh` | The script. Single file, no external sourcing. |
| `README.md` | User-facing documentation: usage, flags, examples, exit codes. |
| `AGENTS.md` | This file. |

## Ground rules for changes

1. **Single-file, dependency-free.** Do not introduce a requirement on
   anything beyond bash + git (no python, no jq, no third-party binaries).
   If a change needs a dependency, stop and flag it instead of adding it
   silently.
2. **POSIX-ish bash, but bash-specific features are fine** (the shebang is
   `#!/usr/bin/env bash`, and it already uses bash-isms like `mapfile` and
   process substitution `< <(...)`). Don't rewrite it to be `sh`-compatible.
3. **Preserve the exit code contract**: `0` = clean, `1` = issues found,
   `2` = bad path. Anything that changes this needs to be called out
   explicitly in README.md.
4. **Don't change flag behavior silently.** `-f` (fetch) and `-q` (quiet)
   are documented in README.md — if you add, rename, or change a flag,
   update README.md in the same change.
5. **Subshell scoping matters.** Each repo is processed in a subshell
   (`( cd "$repo" || exit 0; ... )`) so a `cd` or failure in one repo can't
   affect the scan of the next. Findings are written to per-run temp files
   (`/tmp/git-audit-*.$$`) because variables set inside a subshell don't
   propagate to the parent shell — that's why the summary counts are
   reconstructed from those temp files after the main loop. If you touch
   this logic, keep that pattern or replace it with something equally
   leak-proof (e.g. a named pipe or a single non-subshell loop with careful
   quoting) — don't just move the counters into the subshell and expect them
   to survive.
6. **Clean up temp files.** The `/tmp/git-audit-*.$$` files are removed
   after being read. Any new temp-file usage must also clean up after itself,
   including on early exit / error paths.
7. **No network calls unless `-f` is passed.** The default (no-flag) run
   must never touch the network. Fetching only happens inside the
   `if [ "$DO_FETCH" -eq 1 ]` branch — preserve that gate for any new remote
   interaction.

## Testing changes

There's no test suite; validate manually with a throwaway repo set:

```bash
rm -rf /tmp/testrepos && mkdir /tmp/testrepos && cd /tmp/testrepos

git init -q clean-repo && cd clean-repo \
  && git config user.email a@a.com && git config user.name a \
  && echo hi > f && git add . && git commit -qm init && cd ..

git init -q dirty-repo && cd dirty-repo \
  && git config user.email a@a.com && git config user.name a \
  && echo hi > f && git add . && git commit -qm init \
  && echo more >> f && cd ..

git init -q noremote-repo && cd noremote-repo \
  && git config user.email a@a.com && git config user.name a \
  && echo hi > f && git add . && git commit -qm init && cd ..

bash /path/to/git-audit.sh /tmp/testrepos
```

At minimum, check:

- Syntax is valid: `bash -n git-audit.sh`
- Script runs against the fixture above and correctly flags:
  - `dirty-repo` as `[DIRTY]`
  - all three repos as `[NO REMOTE]` (none have a configured remote)
- Exit code is `1` when issues exist, `0` when scanning only clean repos.
- `-q` suppresses the "clean" line for repos with no findings.
- `--help` / `-h` prints usage and exits `0` without scanning anything.

For a true "unpushed" test, you'd need a repo with an actual remote (e.g. a
local bare repo used as the "remote"):

```bash
git init -q --bare /tmp/bare-remote.git
git init -q /tmp/testrepos/pushed-repo
cd /tmp/testrepos/pushed-repo
git config user.email a@a.com && git config user.name a
echo hi > f && git add . && git commit -qm init
git remote add origin /tmp/bare-remote.git
git push -u -q origin main
echo more >> f && git add . && git commit -qm second
# now this branch is 1 commit ahead of origin/main
```

## Style notes

- Keep output colorized only when attached to a terminal (`[ -t 1 ]` check
  already gates this) — don't emit raw ANSI codes when piped/redirected.
- Prefer clear, skimmable per-repo output (`[DIRTY]`, `[NO REMOTE]`,
  `[UNPUSHED]` tags) over verbose prose, so the tool stays useful for
  scanning dozens of repos at a glance.
- Keep the summary block at the end — it's what people scan first.
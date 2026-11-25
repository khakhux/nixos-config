---
name: Secrets (agenix)
description: Manage agenix secrets in this NixOS config. Use when adding, editing, decrypting, or re-keying a secret, or wiring a secret into a module. Triggers on "add secret", "create secret", "encrypt", "re-key", or a service needing credentials/API keys/env vars.
---

# Secrets (agenix)

Single-host setup (`currolaptop`). Recipients live in `secrets/agenix-rules.nix`
(currently only the `cacu` user key). Encrypted blobs live next to it as
`secrets/*.age`. Never commit plaintext secrets or private keys.

## `agenix` is not on PATH here

Don't run bare `agenix`. Use:

```bash
nix run github:ryantm/agenix -- <args>
```

## Critical: run from `secrets/`

agenix finds `agenix-rules.nix` in the **current directory or any parent**, and
resolves rule keys relative to that file. Run from `secrets/` (or a
subdirectory) and pass bare filenames (`github-token.age`), not
`secrets/github-token.age` — prefixed paths fail with `There is no rule for ...`
because keys are resolved relative to the rules file. From the repo root, set
`AGENIX_RULES=secrets/agenix-rules.nix`.

Decryption identity is `/home/cacu/.ssh/id_github` (forced by
`age.identityPaths` in `hosts/currolaptop/configuration.nix`). agenix only
auto-detects `id_rsa`/`id_ed25519`, so pass `-i` explicitly when decrypting.

## Create a new secret

1. Register it in `secrets/agenix-rules.nix`:
   ```nix
   { "<name>.age".publicKeys = [ cacu ]; }
   ```
2. Encrypt from `secrets/`. Piped stdin replaces the cleartext and needs no
   editor or decryption identity:
   ```bash
   cd secrets
   printf 'SECRET_VALUE' | nix run github:ryantm/agenix -- -e <name>.age
   ```
   Ask the user for the value if it must not pass through the shell history;
   never invent a value.
3. Verify it decrypts before trusting it (pipes fail silently):
   ```bash
   nix run github:ryantm/agenix -- -d <name>.age -i ~/.ssh/id_github >/dev/null && echo ok
   ```
   Never print the plaintext to the conversation.
4. From the repo root: `git add secrets/<name>.age secrets/agenix-rules.nix`.

## Edit / view an existing secret

```bash
cd secrets
nix run github:ryantm/agenix -- -e <name>.age -i ~/.ssh/id_github  # $EDITOR, or pipe via stdin
nix run github:ryantm/agenix -- -d <name>.age -i ~/.ssh/id_github  # decrypt to stdout (avoid)
```

## Check / re-key

```bash
cd secrets
nix run github:ryantm/agenix -- -c                      # recipients match agenix-rules.nix
nix run github:ryantm/agenix -- -r -i ~/.ssh/id_github  # re-encrypt after a recipient change
cd .. && git add secrets/*.age secrets/agenix-rules.nix
```

`-c` is safe: it reads the age header only, never the plaintext.

## Consuming a secret in a module

Declare it in `modules-dev/configuration.nix` (or the host config):

```nix
age.secrets.<name> = {
  file = ../secrets/<name>.age;   # ../../secrets/... from hosts/currolaptop/
  owner = envs.mainUser;
  mode = "0400";
};
```

Then point the consumer at `config.age.secrets.<name>.path` (runtime path
`/run/agenix/<name>`). Existing pattern in this repo: the GitHub token is
included by `nix.extraOptions`:

```nix
nix.extraOptions = ''
  !include ${config.age.secrets.github-token.path}
'';
```

Match the shape the target NixOS option expects; don't invent a new one.

## Verify after `nrs`

```bash
sudo -u cacu test -r /run/agenix/<name> && echo "secret is readable"
```

Check access with `stat` (mode/owner), never with `cat`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `agenix needs a rules file` / `There is no rule for ...` | ran from repo root, or key still prefixed with `secrets/` | `cd secrets` (or set `AGENIX_RULES=secrets/agenix-rules.nix`), use bare filenames and keys |
| `No identity found` | default identities are `id_rsa`/`id_ed25519` | add `-i ~/.ssh/id_github` |
| decrypts to empty/garbage | a piped-in value generator failed silently | verify the plaintext, then `-d` after `-e` |
| `permission denied` in a user service | secret is root-owned | set `owner`/`group`; do not widen the mode |
| host can't decrypt at runtime | `cacu` missing from that secret's `publicKeys` | add it to `secrets/agenix-rules.nix`, `-r`, redeploy |

Adapted from [edrobertsrayne/nix-config](https://github.com/edrobertsrayne/nix-config/blob/main/.claude/skills/secrets/SKILL.md).

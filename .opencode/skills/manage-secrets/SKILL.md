---
name: Manage Secrets (agenix)
description: Checklist-style alternative to the `secrets` skill for adding or modifying an agenix secret in this NixOS config (encrypt, register recipient in secrets/agenix-rules.nix, declare age.secrets, rebuild and verify)
---

# Manage Secrets (agenix)

Alternative to the `secrets` skill; load this one explicitly when you want the
repo-specific checklist. This repo stores secrets as agenix-encrypted files in
`secrets/`. Never commit plaintext secrets or private keys, and never print a
secret's value.

- Recipients: `secrets/agenix-rules.nix` (key names are bare filenames such as
  `github-token.age`).
- Decryption identity: `/home/cacu/.ssh/id_github`, forced via
  `age.identityPaths` in `hosts/currolaptop/configuration.nix`.
- Existing example: `secrets/github-token.age`, declared in
  `modules-dev/configuration.nix` and included by `nix.extraOptions`.

## Critical: run from `secrets/`

agenix discovers `agenix-rules.nix` in the current directory or any parent
directory, and resolves rule keys relative to it. Run from `secrets/` (or a
subdirectory) and pass bare filenames; a prefixed key like
`secrets/github-token.age` would point at `secrets/secrets/github-token.age`.
From the repo root, set `AGENIX_RULES=secrets/agenix-rules.nix`.

## Workflow

1. Encrypt or edit the secret file from `secrets/`. Piped stdin replaces the
   cleartext without an editor or decryption identity; with a TTY, `$EDITOR`
   opens after decrypting:

   ```bash
   cd secrets
   printf 'VALUE' | nix run github:ryantm/agenix -- -e <name>.age
   nix run github:ryantm/agenix -- -e <name>.age -i ~/.ssh/id_github  # interactive
   ```

   Ask the user for the value if it must not pass through shell history; never
   invent one.

2. Register the recipient in `secrets/agenix-rules.nix`:

   ```nix
   { "<name>.age".publicKeys = [ cacu ]; }
   ```

   `cacu` is the existing `ssh-ed25519 ... cacu@mininas` key. If a new recipient
   is required, ask the user for its public key.

3. Verify the ciphertext before trusting it (silent pipe failures are common):

   ```bash
   nix run github:ryantm/agenix -- -d <name>.age -i ~/.ssh/id_github >/dev/null && echo ok
   nix run github:ryantm/agenix -- -c   # recipients match agenix-rules.nix; never reads plaintext
   ```

4. Declare the secret in the system configuration (normally
   `modules-dev/configuration.nix`) and consume it through
   `config.age.secrets.<name>.path`:

   ```nix
   age.secrets.<name> = {
     file = ../secrets/<name>.age; # ../../secrets/... from hosts/currolaptop/
     owner = envs.mainUser;
     mode = "0400";
   };
   ```

   Use `envs.mainUser` (from `hosts/currolaptop/user.nix`) rather than a
   hardcoded user. Grant only the minimum mode/owner the consumer needs. Never
   read the secret at evaluation time with `builtins.readFile` — the Nix store
   is world-readable.

5. Apply the configuration:

   ```bash
   nrs
   ```

6. Verify the secret was installed without displaying its contents:

   ```bash
   sudo -u cacu test -r /run/agenix/<name> && echo "secret is readable"
   stat -c '%a %U:%G' /run/agenix/<name>
   ```

   Then check the consuming service/config works (for example
   `nix flake update` for the GitHub token).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `There is no rule for ...` | wrong cwd, or prefixed key | `cd secrets`, bare filenames, bare keys |
| `No identity found` | agenix only auto-detects `id_rsa`/`id_ed25519` | pass `-i ~/.ssh/id_github` |
| decrypts to empty/garbage | piped generator failed silently | verify plaintext, `-d` after `-e` |
| `permission denied` in a user service | root-owned secret | set `owner`/`group`; do not widen the mode |
| host can't decrypt at runtime | `cacu` missing from `publicKeys` | add it, `-r -i ~/.ssh/id_github`, redeploy |

## Checks

- `nix-instantiate --parse secrets/agenix-rules.nix` after editing it.
- `git status` must not show decrypted files, keys, or `.age` edits made outside
  the agenix editor.

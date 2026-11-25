---
name: Manage Secrets (agenix)
description: Add or modify an agenix-managed secret in this NixOS config (encrypt with agenix, register recipient in secrets.nix, declare age.secrets, rebuild and verify)
---

# Manage Secrets (agenix)

This repo stores secrets as agenix-encrypted files in `secrets/`. Never commit
plaintext secrets or private keys, and never print a secret's value.

- Recipients: `secrets.nix` at the repo root (there is no `secrets/secrets.nix`).
- Decryption identity: `/home/cacu/.ssh/id_github`, forced via `age.identityPaths`
  in `hosts/currolaptop/configuration.nix`.
- Existing example: `secrets/github-token.age`, declared in
  `modules-dev/configuration.nix` and included by `nix.extraOptions`.

## Workflow

1. Encrypt or edit the secret file. Editing an existing `.age` file decrypts then
   re-encrypts it:

   ```bash
   nix run github:ryantm.agenix -- -e secrets/<name>.age -i ~/.ssh/id_github
   ```

2. Register the recipient in the root `secrets.nix`:

   ```nix
   { "secrets/<name>.age".publicKeys = [ cacu ]; }
   ```

   `cacu` is the existing `ssh-ed25519 ... cacu@mininas` public key. If a new
   recipient is required, ask the user for its public key; do not invent one.

3. Declare the secret in the system configuration (normally
   `modules-dev/configuration.nix`) and consume it through
   `config.age.secrets.<name>.path`:

   ```nix
   age.secrets.<name> = {
     file = ../secrets/<name>.age; # adjust depth: ../../secrets from hosts/
     owner = envs.mainUser;
     mode = "0400";
   };
   ```

   Use `envs.mainUser` (from `hosts/currolaptop/user.nix`) rather than a
   hardcoded user. Grant only the minimum mode/owner the consumer needs.

4. Apply the configuration:

   ```bash
   nrs
   ```

5. Verify the secret was installed without displaying its contents:

   ```bash
   sudo -u cacu test -r /run/agenix/<name> && echo "secret is readable"
   ```

   Then check the consuming service/config works (for example
   `nix flake update` for the GitHub token).

## Checks

- `nix-instantiate --parse secrets.nix` after editing it.
- `git status` must not show decrypted files, keys, or `.age` edits made outside
  the agenix editor.
- If a rebuild fails on decryption, confirm `secrets/<name>.age` is listed in
  `secrets.nix` for `cacu` and that `~/.ssh/id_github` exists.

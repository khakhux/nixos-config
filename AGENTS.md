# AGENTS.md — NixOS Config

Personal NixOS flake for a single active host (`currolaptop`, WSL2 on Windows). The `modules/` tree is mostly library/template code; the live configuration lives in `modules-dev/` and `hosts/currolaptop/`. For routine updates, follow [nix-update.md](nix-update.md).

## Apply the config

```bash
# Short alias (defined in modules-dev/home.nix and modules/common-home.nix):
nrs
# Expands to:
sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#$(hostname)

# Full form (if alias unavailable):
sudo nixos-rebuild switch --flake /path/to/nixos-config#currolaptop

# Behind corporate proxy (first bootstrap only):
sudo nixos-rebuild switch --flake ... --option ssl-cert-file /etc/ssl/proxy-certs/CARaiz.pem
```

There is no CI, Makefile, linter, or test suite. For a lightweight check, parse changed Nix files with `nix-instantiate --parse` and evaluate relevant flake attributes with `nix eval`. The full system check is a successful `nixos-rebuild switch`.

## Update opencode (unstable input)

```bash
./scripts/update-opencode.sh            # checks version bump in nixpkgs-unstable
./scripts/update-opencode.sh --rebuild  # also rebuilds currolaptop immediately
```

`opencode`, `openspec`, and `codex` are installed from `pkgsUnstable`, not stable nixpkgs. This script updates only the `nixpkgs-unstable` lock entry.

## Dev shell (Java/Maven/IntelliJ)

```bash
cd dev-envs/java21 && nix develop          # standard (no corp CA)
# or use the alias:
idea-java21
```

`currolaptop` also adds `uv` and puts `~/.local/bin` on `PATH` so GitHub Spec Kit helpers are reachable.

## Key architecture facts

- **One configured host**: `currolaptop`. The flake also declares `server-docker-01`, `mininas`, and `minipc-n150`, but their `hosts/` directories do not exist — evaluating or building those configurations will fail until the host files are added.
- **`system` is hardcoded to `x86_64-linux`** in the `mkHost` factory in `flake.nix`. All hosts share this.
- **`nixos-wsl.nixosModules.default` is loaded unconditionally for every host** in `mkHost`. Adding a non-WSL host requires restructuring `mkHost` or explicitly setting `wsl.enable = false`.
- **`hosts/currolaptop/user.nix` is a plain attrset, not a NixOS module.** `hosts/currolaptop/home.nix` imports it as `users` for host-specific modules and passes its path to `modules-dev/home.nix` as `envFilePath`; `modules-dev/home.nix` imports it as `envs` for common user configuration.
- **SSH configuration is split by scope.** `modules/home/programs/ssh/common.nix` and `desktop.nix` are imported by `hosts/currolaptop/home.nix`; `modules-dev/home.nix` imports `modules-dev/home/programs/ssh/work.nix` and passes it the imported user data. The work GitLab block gets its login from `gitUser`.
- **Home Manager SSH blocks use `programs.ssh.matchBlocks`.** Use Home Manager's lowercase option names such as `hostname`, `user`, `identityFile`, and `identitiesOnly`; `programs.ssh.settings` is not available in the pinned Home Manager release.
- **`pkgsUnstable`** is threaded through `specialArgs` and available in any module that declares it in its function signature.
- **`modules/common-configuration.nix`** and **`modules/git.nix`** reference `../users.nix` which does not exist at the repo root. Do not import these modules; they would fail to evaluate.

## Directory map

| Path | Role |
|---|---|
| `hosts/currolaptop/` | The only active host (WSL2) |
| `hosts/currolaptop/user.nix` | Pure data: `mainUser`, `hostname`, `gitUser`, `gitEmail` |
| `modules-dev/configuration.nix` | Active system config: Docker, corp CA, dev packages |
| `modules-dev/home.nix` | Shared Home Manager config: git, direnv, SOPS, corp CA bundle; imports work SSH config |
| `modules-dev/home/programs/ssh/work.nix` | Work GitLab SSH block; uses `users.gitUser` |
| `modules-dev/cacerts/CARaiz.pem` | Corporate root CA (IGAE/MINHAC Spain); do not remove |
| `modules/` | Library/template modules — mostly unused by active hosts |
| `modules/nvim/` | Neovim home-manager module; imported by `currolaptop/home.nix` |
| `modules/home/programs/ssh/` | Common and desktop SSH blocks; imported by `currolaptop/home.nix` |
| `modules/wsl.nix` | WSL2 shim; imported by `currolaptop/configuration.nix` |
| `modules/docker.nix` | Docker; imported by `modules-dev/configuration.nix` |
| `dev-envs/java21/` | Dev shell: JDK 21.0.13 + Maven 3.9.8 + IntelliJ |
| `scripts/update-opencode.sh` | Only automation script |
| `secrets/` + `secrets.nix` | agenix encrypted secret files and their recipient public keys |

## Corporate environment notes

- `modules-dev/home.nix` fetches a **private internal GitLab repo** (`metodologia`) at build time using `pkgs.fetchgit` with a pinned SHA. This requires SSH access to `gitlab.central.sepg.minhac.age` during rebuild. Update the `rev` and `sha256` in that file when the repo changes.
- `docker pull` against `harbor.dockersl.central.sepg.minhac.age` needs Docker daemon trust in addition to the normal system CA bundle. The Harbor certificate chain uses the `Comunica2` intermediate under `CARaiz`, and `modules-dev/configuration.nix` now installs both certificates into `security.pki.certificateFiles` and writes a combined bundle to `/etc/docker/certs.d/harbor.dockersl.central.sepg.minhac.age/ca.crt` for the daemon.
- An **age key** is auto-generated on first home-manager activation (`~/.config/sops/age/keys.txt`). After generation, add the public key to `.sops.yaml` files in other repos that use SOPS encryption.
- `home-manager.backupFileExtension = "backup"` is set globally — conflicting unmanaged files are renamed to `<file>.backup` rather than causing a failure.

## Secrets (agenix)

Secrets are agenix-encrypted files in `secrets/`, registered in `secrets.nix`.
Never commit plaintext secrets or private keys. For any change that adds or
modifies a secret, load the `manage-secrets` skill
(`.opencode/skills/manage-secrets/SKILL.md`).

## Nix channels

| Input | Pin | Used for |
|---|---|---|
| `nixpkgs` | `nixos-25.05` | Everything (stable) |
| `nixpkgs-unstable` | rolling | `opencode` and select packages via `pkgsUnstable` |
| `home-manager` | `release-25.05` | Follows stable nixpkgs |
| `nixos-wsl` | `release-25.05` | WSL2 integration; now follows `nixpkgs-unstable` |

# AGENTS.md — NixOS Config

Personal NixOS flake. The active hosts are `currolaptop` (NixOS-WSL2), `mininas` (server), and `minipc-n150` (desktop); see [hosts/README.md](hosts/README.md). The `modules/` tree is mostly library/template code; live configurations are in `hosts/` and shared modules. For routine updates, follow [nix-update.md](nix-update.md).

## Apply the config

```bash
# Before any host-specific evaluation, build, test, or apply:
hostname
# Confirm this is the intended active host and that its name matches the flake target.

# Short alias (defined in modules-dev/home.nix and modules/common-home.nix):
nrs
# Expands to:
sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#$(hostname)

# Full form (if alias unavailable):
sudo nixos-rebuild switch --flake /path/to/nixos-config#currolaptop

# Behind corporate proxy (first bootstrap only):
sudo nixos-rebuild switch --flake ... --option ssl-cert-file /etc/ssl/proxy-certs/CARaiz.pem
```

There is no CI, Makefile, linter, or test suite. Before host-specific checks or rebuilds, run `hostname` and confirm the intended host target; do not assume the current host from prior session context. For a lightweight check, parse changed Nix files with `nix-instantiate --parse` and evaluate the intended host's flake attribute with `nix eval`. The full system check is a successful `nixos-rebuild switch`.

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

- **Active hosts**: `currolaptop`, `mininas`, and `minipc-n150`. Other host directories/configurations are legacy or incomplete; see [hosts/README.md](hosts/README.md) and do not treat them as active without confirmation.
- **`system` is hardcoded to `x86_64-linux`** in the `mkHost` factory in `flake.nix`. All hosts share this.
- **`nixos-wsl.nixosModules.default` is loaded unconditionally for every flake host** in `mkHost`. This matches `currolaptop` only; native `mininas` and `minipc-n150` need a platform-aware host factory before using those flake outputs to build/apply. See `hosts/README.md`.
- **`hosts/currolaptop/user.nix` is a plain attrset, not a NixOS module.** `hosts/currolaptop/home.nix` imports it as `users` for host-specific modules and passes its path to `modules-dev/home.nix` as `envFilePath`; `modules-dev/home.nix` imports it as `envs` for common user configuration.
- **SSH configuration is split by scope.** `modules/home/programs/ssh/common.nix` and `desktop.nix` are imported by `hosts/currolaptop/home.nix`; `modules-dev/home.nix` imports `modules-dev/home/programs/ssh/work.nix` and passes it the imported user data. The work GitLab block gets its login from `gitUser`.
- **Home Manager SSH blocks use `programs.ssh.matchBlocks`.** Use Home Manager's lowercase option names such as `hostname`, `user`, `identityFile`, and `identitiesOnly`; `programs.ssh.settings` is not available in the pinned Home Manager release.
- **Agenix system identity transition**: `hosts/currolaptop/configuration.nix` now uses agenix's default `/etc/ssh/ssh_host_*` identities. Before applying that change on `currolaptop`, generate its host key with `sudo ssh-keygen -A`, add the host public key to `secrets/agenix-rules.nix` alongside the user recipient, then rekey. Keep the user recipient for CLI editing/recovery; do not use another host's key.
- **`pkgsUnstable`** is threaded through `specialArgs` and available in any module that declares it in its function signature.
- **`modules/common-configuration.nix`** and **`modules/git.nix`** reference `../users.nix` which does not exist at the repo root. Do not import these modules; they would fail to evaluate.

## Directory map

| Path | Role |
|---|---|
| `hosts/` | Active host descriptions in `hosts/README.md` |
| `hosts/currolaptop/` | Active WSL2 development host |
| `hosts/servers/mininas/` | Active native NixOS server |
| `hosts/desktops/minipc-n150/` | Active native NixOS desktop |
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
| `secrets/` | agenix encrypted secret files and `secrets/agenix-rules.nix` recipient keys |

## Corporate environment notes

- `modules-dev/home.nix` fetches a **private internal GitLab repo** (`metodologia`) at build time using `pkgs.fetchgit` with a pinned SHA. This requires SSH access to `gitlab.central.sepg.minhac.age` during rebuild. Update the `rev` and `sha256` in that file when the repo changes.
- `docker pull` against `harbor.dockersl.central.sepg.minhac.age` needs Docker daemon trust in addition to the normal system CA bundle. The Harbor certificate chain uses the `Comunica2` intermediate under `CARaiz`, and `modules-dev/configuration.nix` now installs both certificates into `security.pki.certificateFiles` and writes a combined bundle to `/etc/docker/certs.d/harbor.dockersl.central.sepg.minhac.age/ca.crt` for the daemon.
- An **age key** is auto-generated on first home-manager activation (`~/.config/sops/age/keys.txt`). After generation, add the public key to `.sops.yaml` files in other repos that use SOPS encryption.
- `home-manager.backupFileExtension = "backup"` is set globally — conflicting unmanaged files are renamed to `<file>.backup` rather than causing a failure.

## Secrets (agenix)

Secrets are agenix-encrypted files in `secrets/`, with recipients in
`secrets/agenix-rules.nix`. Never commit plaintext secrets or private keys.
For secret changes, load the `secrets` skill.

## Nix channels

| Input | Pin | Used for |
|---|---|---|
| `nixpkgs` | `nixos-25.05` | Everything (stable) |
| `nixpkgs-unstable` | rolling | `opencode` and select packages via `pkgsUnstable` |
| `home-manager` | `release-25.05` | Follows stable nixpkgs |
| `nixos-wsl` | `release-25.05` | WSL2 integration; now follows `nixpkgs-unstable` |

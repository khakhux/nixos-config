# AGENTS.md — NixOS Config

Personal NixOS flake for a single active host (`currolaptop`, WSL2 on Windows). The `modules/` tree is mostly library/template code; the live configuration lives in `modules-dev/` and `hosts/currolaptop/`.

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

There is no CI, no Makefile, no linter, and no test suite. The only verification is a successful `nixos-rebuild switch`.

## Update opencode (unstable input)

```bash
./scripts/update-opencode.sh            # checks version bump in nixpkgs-unstable
./scripts/update-opencode.sh --rebuild  # also rebuilds currolaptop immediately
```

`opencode` is installed from `pkgsUnstable`, not stable nixpkgs. This script updates only the `nixpkgs-unstable` lock entry.

## Dev shell (Java/Maven/IntelliJ)

```bash
cd dev-envs/java21 && nix develop          # standard (no corp CA)
# or use the alias:
idea-java21
```

Use `dev-envs/java21/flake-caraiz.nix` instead when behind the corporate proxy — it bakes `CARaiz.pem` into the JDK cacerts keystore.

## Key architecture facts

- **One live host**: `currolaptop`. The flake also declares `server-docker-01` and `mininas`, but their `hosts/` directories do not exist — evaluating or building them will fail.
- **`system` is hardcoded to `x86_64-linux`** in the `mkHost` factory in `flake.nix`. All hosts share this.
- **`nixos-wsl.nixosModules.default` is loaded unconditionally for every host** in `mkHost`. Adding a non-WSL host requires restructuring `mkHost` or explicitly setting `wsl.enable = false`.
- **`user.nix` is a plain attrset, not a NixOS module.** It is `import`-ed directly to get `mainUser`, `hostname`, `gitUser`, `gitEmail`. It is passed as `envFilePath` into `modules-dev/` files, which re-import it themselves.
- **`pkgsUnstable`** is threaded through `specialArgs` and available in any module that declares it in its function signature.
- **`modules/common-configuration.nix`** and **`modules/git.nix`** reference `../users.nix` which does not exist at the repo root. Do not import these modules; they would fail to evaluate.

## Directory map

| Path | Role |
|---|---|
| `hosts/currolaptop/` | The only active host (WSL2) |
| `hosts/currolaptop/user.nix` | Pure data: `mainUser`, `hostname`, `gitUser`, `gitEmail` |
| `modules-dev/configuration.nix` | Active system config: Docker, corp CA, dev packages |
| `modules-dev/home.nix` | Active home-manager config: git, direnv, SOPS, corp CA bundle |
| `modules-dev/cacerts/CARaiz.pem` | Corporate root CA (IGAE/MINHAC Spain); do not remove |
| `modules/` | Library/template modules — mostly unused by active hosts |
| `modules/nvim/` | Neovim home-manager module; imported by `currolaptop/home.nix` |
| `modules/wsl.nix` | WSL2 shim; imported by `currolaptop/configuration.nix` |
| `modules/docker.nix` | Docker; imported by `modules-dev/configuration.nix` |
| `dev-envs/java21/` | Dev shell: pinned JDK 21 + Maven 3.8.6 + IntelliJ |
| `scripts/update-opencode.sh` | Only automation script |

## Corporate environment notes

- `modules-dev/home.nix` fetches a **private internal GitLab repo** (`metodologia`) at build time using `pkgs.fetchgit` with a pinned SHA. This requires SSH access to `gitlab.central.sepg.minhac.age` during rebuild. Update the `rev` and `sha256` in that file when the repo changes.
- An **age key** is auto-generated on first home-manager activation (`~/.config/sops/age/keys.txt`). After generation, add the public key to `.sops.yaml` files in other repos that use SOPS encryption.
- `home-manager.backupFileExtension = "backup"` is set globally — conflicting unmanaged files are renamed to `<file>.backup` rather than causing a failure.

## Nix channels

| Input | Pin | Used for |
|---|---|---|
| `nixpkgs` | `nixos-25.05` | Everything (stable) |
| `nixpkgs-unstable` | rolling | `opencode` and select packages via `pkgsUnstable` |
| `home-manager` | `release-25.05` | Follows stable nixpkgs |
| `nixos-wsl` | `main` | WSL2 integration |

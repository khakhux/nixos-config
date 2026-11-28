# NixOS configuration

Personal NixOS flake. The active hosts are `currolaptop` (NixOS-WSL), `mininas` (server), and `minipc-n150` (desktop). Other host directories are legacy or incomplete; see [hosts/README.md](hosts/README.md). Shared settings live in `modules/` and `modules-dev/`.

For routine Nix input and system updates, see [nix-update.md](nix-update.md). Agent-facing architecture and maintenance notes are in [AGENTS.md](AGENTS.md).

## Repository layout

```text
.
├── flake.nix
├── hosts/
│   ├── currolaptop/             # WSL development host
│   ├── servers/
│   │   ├── mininas/
│   │   └── server-docker-01/    # incomplete legacy host
│   └── desktops/
│       ├── minipc-n150/
│       ├── minipc-n100/
│       ├── desktop-qtile/
│       └── proxmox-desktop/
├── modules-dev/
│   ├── configuration.nix       # WSL development system settings
│   ├── home.nix                 # WSL development Home Manager settings
│   ├── home/programs/ssh/work.nix
│   └── cacerts/
├── modules/
│   ├── common-configuration.nix # shared system settings and GitHub token
│   ├── server.nix               # common + SSH server + static networking
│   ├── desktop.nix              # common desktop system settings
│   ├── ssh-server.nix           # hardened SSH, authorized keys, port 22
│   ├── home/programs/ssh/       # common and desktop SSH blocks
│   ├── nvim/                    # neovim config
│   ├── docker.nix               # docker engine config
│   └── wsl.nix                  # wsl config
├── dev-envs/java21/
├── secrets/
│   ├── agenix-rules.nix        # agenix recipients
│   └── github-token.age        # github access token for `nix flake update` api usage limits
└── scripts/
    └── check-fast.sh           # simple nixos config test
```

`hosts/currolaptop/user.nix` is a plain Nix attrset, not a NixOS module. The host's `home.nix` imports it for host-specific settings and passes its path to `modules-dev/home.nix` as `envFilePath`. The shared home module imports it for common user configuration and imports the work SSH module.

## Shared system and SSH configuration

`modules/common-configuration.nix` supplies settings shared by native hosts, including the agenix GitHub token used by Nix. `modules/server.nix` adds `modules/ssh-server.nix` (hardened OpenSSH, authorized keys, and SSH firewall access) and static networking; each server passes its own interface and IP address. `modules/desktop.nix` currently imports only the common module. `minipc-n150` sets its agenix decryption identity in its host configuration. The flake selects `hosts/servers/<name>/` or `hosts/desktops/<name>/` through `hostGroup`, while `currolaptop` remains directly under `hosts/`.

SSH *client* settings are separate Home Manager modules: `modules/home/programs/ssh/common.nix` and `desktop.nix` define personal and home-network hosts; `modules-dev/home/programs/ssh/work.nix` defines the work GitLab host. Home Manager uses `programs.ssh.matchBlocks` with lowercase keys such as `hostname`, `user`, `identityFile`, and `identitiesOnly`.

## Apply the configuration

On `currolaptop`, the `nrs` shell alias runs:

```sh
sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#$(hostname)
```

Equivalent explicit command:

```sh
sudo nixos-rebuild switch --flake /path/to/nixos-config#currolaptop
```

For a first rebuild behind the corporate proxy, the configured corporate CA may need to be supplied explicitly:

```sh
sudo nixos-rebuild switch --flake /path/to/nixos-config#currolaptop \
  --option ssl-cert-file /etc/ssl/proxy-certs/CARaiz.pem
```

The flake also declares `server-docker-01`, `mininas`, and `minipc-n150`.
Server and desktop configurations are under `hosts/servers/` and
`hosts/desktops/` respectively. `server-docker-01` is incomplete; see
`hosts/README.md` for active hosts. The NixOS-WSL module is loaded only for
`currolaptop`.

There is no CI or full test suite. After confirming `hostname` matches the intended flake target, use `nix eval` for host-specific checks. For changed Nix and shell files, run the fast parse/format/lint checks documented in [hosts/README.md](hosts/README.md). The full system validation is a successful `nixos-rebuild switch`.

## Corporate Docker registry

Pulls from `harbor.dockersl.central.sepg.minhac.age` need the corporate certificate chain trusted by Docker itself, in addition to the system trust store. `modules-dev/configuration.nix` installs the required certificates and writes a combined bundle to:

```text
/etc/docker/certs.d/harbor.dockersl.central.sepg.minhac.age/ca.crt
```

If Docker does not pick up a trust-store change immediately, restart it with `sudo systemctl restart docker`.

## Java development shell

The Java 21, Maven, and IntelliJ environment is in `dev-envs/java21/`:

```sh
cd dev-envs/java21 && nix develop
# or, from the configured home environment:
idea-java21
```

`currolaptop` also adds `uv` and `~/.local/bin` to the environment for GitHub Spec Kit helpers.

## Update OpenCode

`opencode`, `openspec`, and `codex` are installed from `nixpkgs-unstable`. The helper updates only that flake input:

```sh
./scripts/update-opencode.sh
./scripts/update-opencode.sh --rebuild
```

## Add secrets

This flake uses [agenix](https://github.com/ryantm/agenix/) for secrets, including the GitHub token used by `nix flake update`. Native hosts declare the token in `modules/common-configuration.nix`; `currolaptop` declares it in `modules-dev/configuration.nix`.

Private keys and other more sensible data are not included in the repo, with or without agenix.

There are other options such as [sops-nix](https://mynixos.com/sops-nix) (more complex) or [sops](https://getsops.io/) (more complex and secrets are in plain on worktree). There is also [SecretSpec](https://secretspec.dev/) but is target is to encrypt properties on application development (see [SecretSpec vs SOPS](https://secretspec.dev/blog/but-i-use-sops/)).

agenix refs:
- https://ryantm.github.io/agenix/tutorial/
- https://github.com/ryantm/agenix/blob/main/doc/reference.md

Encrypted files and their rules live in `secrets/`. Use the repo's pinned
`agenix` app from the repo root: `nix run .#agenix -- ...`. It sets
`AGENIX_RULES` to `secrets/agenix-rules.nix`; rule keys are bare filenames.

### 1. Create encrypted property

Example for creating `github-token.age` encrypted with `~/.ssh/id_github` private key:
```shell
nix run .#agenix -- -e github-token.age -i ~/.ssh/id_github
```

Piped input works without an editor and replaces the cleartext directly:
```shell
printf 'VALUE' | nix run .#agenix -- -e github-token.age
```

### 2. Add to agenix config

secrets/agenix-rules.nix
```nix
let
  cacu = "ssh-ed25519 AAAAC3... cacu@mininas";
in
{
  "github-token.age".publicKeys = [ cacu ];
}
```

Check that the recipients match without decrypting:
```shell
nix run .#agenix -- -c
```

```shell
nrs
```

To check that the secret was installed without displaying its contents:
```shell
sudo -u cacu test -r /run/agenix/github-token && echo "GitHub token secret is readable"
```

### 3. Configure token usage

The shared native-host module is `modules/common-configuration.nix`; `modules-dev/configuration.nix` has the same setup for `currolaptop`. The decrypted token must be readable by Nix, and each host needs an agenix identity matching a recipient in `secrets/agenix-rules.nix`.

```nix
  # In modules/common-configuration.nix:
  age.secrets.github-token = {
    file = ../secrets/github-token.age;
    owner = users.mainUser;
    mode = "0400";
  };

  # github access token to be used in nix flake update, file content is: access-tokens = github.com=TOKEN
  nix.extraOptions = ''
    !include ${config.age.secrets.github-token.path}
  '';
```

```shell
nrs
```


# Future Enhancements

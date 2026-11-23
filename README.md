# NixOS configuration

Personal NixOS flake. The only configured host is `currolaptop`, running NixOS-WSL on Windows. The repository also contains reusable modules and templates, but the live host configuration is in `hosts/currolaptop/` and `modules-dev/`.

For routine Nix input and system updates, see [nix-update.md](nix-update.md). Agent-facing architecture and maintenance notes are in [AGENTS.md](AGENTS.md).

## Repository layout

```text
.
├── flake.nix
├── hosts/
│   └── currolaptop/
│       ├── configuration.nix
│       ├── home.nix
│       └── user.nix             # mainUser, hostname, gitUser, gitEmail
├── modules-dev/
│   ├── configuration.nix       # active system settings
│   ├── home.nix                 # shared Home Manager settings
│   ├── home/programs/ssh/work.nix
│   └── cacerts/
├── modules/
│   ├── home/programs/ssh/       # common and desktop SSH blocks
│   ├── nvim/
│   ├── docker.nix
│   └── wsl.nix
├── dev-envs/java21/
└── scripts/update-opencode.sh
```

`hosts/currolaptop/user.nix` is a plain Nix attrset, not a NixOS module. The host's `home.nix` imports it for host-specific settings and passes its path to `modules-dev/home.nix` as `envFilePath`. The shared home module imports it for common user configuration and imports the work SSH module.

## SSH configuration

### Rationale

SSH configuration is split by scope:

- `modules/home/programs/ssh/common.nix` defines common hosts.
- `modules/home/programs/ssh/desktop.nix` defines home-network hosts.
- `modules-dev/home/programs/ssh/work.nix` defines the work GitLab host and gets its login from `gitUser` in `hosts/currolaptop/user.nix`.

Home Manager uses `programs.ssh.matchBlocks` for these host definitions. Use lowercase option names such as `hostname`, `user`, `identityFile`, and `identitiesOnly`; `programs.ssh.settings` is not an option in the pinned Home Manager release.

### Files structure

```text
modules/
└── home/
    ├── common-home.nix (imports common.nix)
    └── programs/
        └── ssh/
            ├── common.nix (ssh common config and github) (we could move ssh settings to ssh-settings.nix)
            └── desktop.nix (mininas, raspberry)
modules-dev/
└── home/
    ├── home.nix (imports work.nix)
    └── programs/
        └── ssh/
            └── work.nix (gitlab)
hosts/
└── currolaptop 
    └── home.nix (imports common.nix, desktop.nix) (imports work.nix through modules-dev/home.nix)
└── minipc-n150
    └── home.nix (imports desktop.nix) (imports common.nix through modules/common-home.nix)
└── mininas, raspberry
    └── home.nix (import common.nix through modules/common-home.nix)
```

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

The flake currently declares `server-docker-01`, `mininas`, and `minipc-n150` as well, but their `hosts/` directories are absent. Only `currolaptop` has a complete host configuration. The host factory also loads the NixOS-WSL module unconditionally, so supporting a non-WSL host requires adjusting that factory.

There is no CI or test suite. For lightweight validation of Nix edits, parse changed files with `nix-instantiate --parse` and evaluate relevant configuration attributes with `nix eval`. The full system validation is a successful `nixos-rebuild switch`.

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

# Future Enhancements


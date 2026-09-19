# Description

My nixos configuration files.

For normal input and system updates, see [nix-update.md](nix-update.md).

# Config files layout

```pgsql
nixos/
├── flake.nix
├── modules-dev/
    └── cacerts/CARaiz.pem
    └── configuration.nix (common config for system)
    └── home.nix (common config for user)
├── modules/
    └── common-configuration.nix
    └── common-home.nix
    └── hardened-ssh.nix
    └── ...
└── hosts/
    └── currolaptop/
        ├── configuration.nix
        └── home.nix
        └── user.nix (user config for host and git)
```

# Installation

After booting nixos using iso or [adding in wsl2](https://nix-community.github.io/NixOS-WSL/install.html)

## Clone repo and create machine specific files

Clone repo

```shell
hostname <hostname>

cd repo/hosts
mkdir $HOSTNAME
cp /etc/nixos/hardware-configuration.nix $HOSTNAME
cp templates/host/*.nix $HOSTNAME
```

- configure user.nix
- add programs to configuration.nix or home.nix

add host to flake.nix
```shell
{
  ...
in {
      nixosConfigurations = {
        server-docker-01 = mkHost "server-docker-01";
        new-server = mkHost "new-server";
      };
    };
}
```

```shell
git add .
```

Verificar cert de https://cache.nixos.org/

```shell
cat /etc/ssl/certs/ca-certificates.crt \
    /home/nixos/nixos-config/modules-dev/cacerts/CARaiz.pem \
    /home/nixos/nixos-config/modules-dev/cacerts/Comunica1.crt \
    /home/nixos/nixos-config/modules-dev/cacerts/Comunica2.crt \
    > /tmp/ca-bundle-with-corp.pem

sudo nixos-rebuild switch --flake /home/nixos/nixos-config#your-hostname \
  --option ssl-cert-file /tmp/ca-bundle-with-corp.pem
```

For Docker pulls from the private Harbor registry behind the corporate TLS-intercepting proxy, the active `modules-dev/configuration.nix` installs `modules-dev/cacerts/CARaiz.pem`, `modules-dev/cacerts/Comunica1.crt`, `modules-dev/cacerts/Comunica2.crt`, and `modules-dev/cacerts/ACCOMP.crt` into the system trust store, and writes a combined bundle to `/etc/docker/certs.d/harbor.dockersl.central.sepg.minhac.age/ca.crt` for the Docker daemon. Harbor currently presents a leaf certificate issued by `Comunica2`, so `CARaiz.pem` alone is not enough.

After `nixos-rebuild switch`, `docker pull harbor.dockersl.central.sepg.minhac.age/...` should complete the TLS handshake successfully. If Docker does not pick it up immediately, restart the daemon with `sudo systemctl restart docker`.

--option substituters http://cache.nixos.org
--option substitute false
https://discourse.nixos.org/t/how-to-install-nixos-with-a-self-signed-cert/55777/2

## Update flake inputs and system

The recommended update flow is documented in [nix-update.md](nix-update.md). The short version is:

```shell
nix flake update
sudo nixos-rebuild test --flake .
sudo nixos-rebuild switch --flake .
```

If you only want to move the unstable toolchain used by `opencode`, `openspec`, and `codex` on `currolaptop`, update just `nixpkgs-unstable`:

```shell
nix flake lock --update-input nixpkgs-unstable
```

## Update opencode from unstable

This repository includes a helper script to update only the `nixpkgs-unstable` input and show the opencode version change.

```shell
./scripts/update-opencode.sh
```

Apply the updated package immediately on `currolaptop`:

```shell
./scripts/update-opencode.sh --rebuild
```

Use a different host name:

```shell
./scripts/update-opencode.sh --host mininas --rebuild
```



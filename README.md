# Description

My nixos configuration files.

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
sudo mkdir -p /etc/ssl/proxy-certs
cat /etc/ssl/certs/ca-certificates.crt \
    /home/nixos/nixos-config/modules-dev/cacerts/Comunica1.crt \
    > /etc/ssl/proxy-certs/ca-bundle-with-corp.pem
sudo chmod 644 /etc/ssl/proxy-certs/CARaiz.pem

sudo nixos-rebuild switch --flake /home/nixos/nixos-config#your-hostname \
  --option ssl-cert-file /etc/ssl/proxy-certs/ca-bundle-with-corp.pem
```

For Docker pulls from the private Harbor registry behind the corporate TLS-intercepting proxy, the active `modules-dev/configuration.nix` installs both `modules-dev/cacerts/CARaiz.pem` and `modules-dev/cacerts/Comunica2.crt` into the system trust store, and writes a combined bundle to `/etc/docker/certs.d/harbor.dockersl.central.sepg.minhac.age/ca.crt` for the Docker daemon. Harbor currently presents a leaf certificate issued by `Comunica2`, so `CARaiz.pem` alone is not enough.

After `nixos-rebuild switch`, `docker pull harbor.dockersl.central.sepg.minhac.age/...` should complete the TLS handshake successfully. If Docker does not pick it up immediately, restart the daemon with `sudo systemctl restart docker`.

--option substituters http://cache.nixos.org
--option substitute false
https://discourse.nixos.org/t/how-to-install-nixos-with-a-self-signed-cert/55777/2

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



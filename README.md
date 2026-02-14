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

```shell
sudo mkdir -p /etc/ssl/proxy-certs
sudo cp /home/nixos/nixos-config/modules-dev/cacerts/CARaiz.pem /etc/ssl/proxy-certs/
sudo chmod 644 /etc/ssl/proxy-certs/CARaiz.pem

sudo nixos-rebuild switch --flake /home/nixos/nixos-config#your-hostname \
  --option ssl-cert-file /etc/ssl/proxy-certs/CARaiz.pem
```

--option substituters http://cache.nixos.org
--option substitute false
https://discourse.nixos.org/t/how-to-install-nixos-with-a-self-signed-cert/55777/2



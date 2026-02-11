# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, envFilePath, ... }:

let
  envs = import envFilePath;
in

{
  imports = [
      ../modules/docker.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
  ];

  wsl.enable = true;
  wsl.defaultUser = envs.mainUser;

  networking = {
    networkmanager.enable = true;
    hostName = envs.hostname;
  };

  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "es_ES.UTF-8";
  console = {
    #   font = "Lat2-Terminus16";
    keyMap = "es";
    #   useXkbConfig = true; # use xkb.options in tty.
  };

  users.users.${envs.mainUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Enable 'sudo' for the user.
  };

  # Create docker_data directory with base compose config
  system.activationScripts.docker-data-setup = ''
    mkdir -p /docker_data
    chown ${envs.mainUser}:users /docker_data
    chmod 755 /docker_data
    
    cat > /docker_data/docker-compose-base.yml << 'EOF'
services:
  ssl-base:
    volumes:
      - /etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-bundle.crt:ro
    environment:
      - SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
EOF
    chown ${envs.mainUser}:users /docker_data/docker-compose-base.yml
  '';

  security.pki.certificateFiles = [
    ./cacerts/CARaiz.pem
  ];

  environment.systemPackages = with pkgs; [
    #https://mynixos.com/nixpkgs/package/
    wget
    jq
    keystore-explorer
    #keepassxc
    #dbvisualizer
    #postman
    #soapui
    #zathura / mupdf #pdf viewer
    #flameshot # screenshot tool
  ];
  
  virtualisation.docker = {
    enable = true;

    daemon.settings = {
      "registry-mirrors" = [
        "https://docker.m.daocloud.io"
      ];
    };
  };

  programs.nix-ld.enable = true; # for remote access via vscode

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05"; # Did you read the comment?
}

# modules/common-configuration.nix
{ config, pkgs, ... }:

let
  users = import ../users.nix;
in

{
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "en_US.UTF-8";
  
  i18n.extraLocaleSettings = {
    LC_TIME = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MESSAGES = "en_US.UTF-8";
  };

  console = {
    #   font = "Lat2-Terminus16";
    keyMap = "es";
    #   useXkbConfig = true; # use xkb.options in tty.
  };

  users.users.${users.mainUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
    packages = with pkgs; [
      tree
    ];
  };

  programs.nix-ld.enable = true; # for remote access via vscode

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    tmux
    usbutils
  ];

  age.secrets.github-token = {
    file = ../secrets/github-token.age;
    owner = users.mainUser;
    mode = "0400";
  };

  # github access token to be used in nix flake update, file content is: access-tokens = github.com=TOKEN
  nix.extraOptions = ''
    !include ${config.age.secrets.github-token.path}
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

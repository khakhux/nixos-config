{ config, pkgs, ... }:

{
  imports = [
    ../../../modules/common-home.nix
    ../../../modules/git.nix
  ];

  home.file.".ssh/known_hosts_nix".source = ./known_hosts;
}

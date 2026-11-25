{ config, pkgs, ... }:

let
  users = import ../../users.nix;
in
{
  imports = [
    ../../modules/common-home.nix
    ../../modules/git.nix
    (import ../../modules/home/programs/ssh/desktop.nix { inherit users; })
    #(import ../../modules/nvim/neovim.nix {
    #  inherit config pkgs;
    #})
  ];

  home.file.".ssh/known_hosts_nix".source = ./known_hosts;
  
  home.packages = with pkgs; [    
    mc # midnight commander, similar to norton commander
    gnome-commander
  ];
}

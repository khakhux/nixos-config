{ config, pkgs, ... }:

let
  users = import ./user.nix;
in
{
  imports = [
    (import ../../modules-dev/home.nix { 
      inherit config pkgs;
      envFilePath = ./user.nix; 
    })
    (import ../../modules/nvim/neovim.nix { 
      inherit config pkgs;
    })
    (import ../../modules/home/programs/ssh/common.nix {})
    (import ../../modules/home/programs/ssh/desktop.nix { inherit users; })
  ];

  home.packages = with pkgs; [    
    mc # midnight commander, similar to norton commander
  ];

  # para github spec kit
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}

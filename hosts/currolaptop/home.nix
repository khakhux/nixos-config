{ config, pkgs, ... }:

{
  imports = [
    (import ../../modules-dev/home.nix { 
      inherit config pkgs;
      envFilePath = ./user.nix; 
    })
    (import ../../modules/nvim/neovim.nix { 
      inherit config pkgs;
    })
  ];

  home.packages = with pkgs; [    
    mc # midnight commander, similar to norton commander
  ];

  # para github spec kit
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}

{ config, pkgs, ... }:

{
  imports = [
    (import ../../modules-dev/home.nix { 
      inherit config pkgs;
      envFilePath = ./user.nix; 
    })
  ];

  home.packages = with pkgs; [    
    neovim
    mc # midnight commander, similar to norton commander
  ];
}

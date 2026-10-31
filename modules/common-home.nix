{ config, pkgs, ... }:

let
  users = import ../users.nix;
in

{
  home.username = users.mainUser;
  home.homeDirectory = "/home/${users.mainUser}";
  home.stateVersion = "25.05";
  programs.bash = {
    enable = true;
    shellAliases = { 
      lcron = "sudo cat /etc/crontab";
    };
    initExtra = ''
      nrs() {
        local host=$(hostname)
        sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#"$host"
      }
    '';
  };

  home.packages = with pkgs; [    
    mc # midnight commander, similar to norton commander
  ];
}

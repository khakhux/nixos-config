{ config, pkgs, mainUser, ... }:

{
  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";
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
}

{ config, pkgs, ... }:

let
  users = import ../users.nix;
in

{
  imports = [
    ./home/programs/ssh/common.nix
  ];

  home.username = users.mainUser;
  home.homeDirectory = "/home/${users.mainUser}";
  home.stateVersion = "25.05";
  # SSH may rewrite known_hosts; keep Home Manager's pinned keys in a separate file.
  programs.ssh.matchBlocks."*".extraOptions.UserKnownHostsFile =
    "~/.ssh/known_hosts ~/.ssh/known_hosts_nix";
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

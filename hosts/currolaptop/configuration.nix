{ config, lib, pkgs, ... }:

let
  envs = import ./user.nix;
in

{
  imports = [
    (import ../../modules-dev/configuration.nix { 
      inherit config lib pkgs;
      envFilePath = ./user.nix; 
    })
    (import ../../modules/wsl.nix { 
      inherit config pkgs;
      mainUser = envs.mainUser; 
    })
  ];

  environment.systemPackages = with pkgs; [
    #https://mynixos.com/nixpkgs/package/
    vscode
    jetbrains.idea-ultimate #/ jetbrains.idea-community
    #node.js
    #python
    #wireshark
    #gh  # GitHub CLI
    #SoapUI
    # firmas
    #asn1js
    #foxe
    #xca
    # dbs
    #dbeaver
    #DbVisualizer
    #HeidiSQL
    # decompilers
    #jadx
    #jd
    opencode
    firefox
    nil          # Nix LSP server for code analysis
    nixpkgs-fmt  # Nix Formatter (alternative is alejandra)
    #arduino
    #nomacs # image viewer 
    #obsidian
    # wrapper with specific JVM options example
    #(writeShellScriptBin "idea" ''
    #  exec ${jetbrains.idea-ultimate}/bin/idea-ultimate \
    #    -Dsun.java2d.xrender=false \
    #    -Dsun.java2d.opengl=false \
    #    -Dawt.useSystemAAFontSettings=lcd \
    #    "$@"
    #'')
    gocatcli
    clipse # clipboard manager https://github.com/savedra1/clipse
    python314
  ];

  #system.activationScripts.make-jdk-dir = "mkdir -p /usr/lib/jvm/default-jdk";
  #fileSystems."/usr/lib/jvm/default-jdk" = {
  #  device = "${pkgs.jdk}/lib/openjdk";
  #  options = [ "bind" ];
  #};  
  
  systemd.tmpfiles.rules = [
    "L+ /workspaces - - - - ${config.users.users.${envs.mainUser}.home}/workspaces"
  ];

  # Clipse clipboard manager listener service
  systemd.user.services.clipse-listener = {
    description = "Clipse clipboard manager listener";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.clipse}/bin/clipse --listen";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}

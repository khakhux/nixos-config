{ config, lib, pkgs, ... }:

{
  imports = [
    (import ../../modules-dev/configuration.nix { 
      inherit config lib pkgs;
      envFilePath = ./user.nix; 
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
  ];

  #system.activationScripts.make-jdk-dir = "mkdir -p /usr/lib/jvm/default-jdk";
  #fileSystems."/usr/lib/jvm/default-jdk" = {
  #  device = "${pkgs.jdk}/lib/openjdk";
  #  options = [ "bind" ];
  #};  
  
}

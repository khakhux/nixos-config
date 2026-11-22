{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.python312
    pkgs.zlib
    pkgs.stdenv.cc.cc
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
      pkgs.zlib
      pkgs.stdenv.cc.cc.lib
    ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    echo "Library path configured:"
    echo "$LD_LIBRARY_PATH"
  '';
}
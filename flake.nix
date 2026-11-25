{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-index-database, nixos-wsl, agenix, ... }:
    let
      system = "x86_64-linux";
      
      mkHost = hostName: 
        let
          users = import ./hosts/${hostName}/user.nix;
          pkgsUnstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgsUnstable;
            inherit nixos-wsl;
          };
          modules = [
            ./hosts/${hostName}/configuration.nix
            nix-index-database.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${users.mainUser} = import ./hosts/${hostName}/home.nix;
              home-manager.backupFileExtension = "backup";
            }
            nixos-wsl.nixosModules.default
            agenix.nixosModules.default
          ];
        };
    in {
      apps.${system}.agenix = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.${system};
          agenixCli = agenix.packages.${system}.default;
        in "${pkgs.writeShellScriptBin "agenix" ''
          export AGENIX_RULES="$(git -C "$PWD" rev-parse --show-toplevel)/secrets/agenix-rules.nix"
          exec ${agenixCli}/bin/agenix "$@"
        ''}/bin/agenix";
      };
      nixosConfigurations = {
        server-docker-01 = mkHost "server-docker-01";
        mininas = mkHost "mininas";
        currolaptop = mkHost "currolaptop";
        minipc-n150 = mkHost "minipc-n150";
        # Add more hosts like this:
        # other-host = mkHost "other-host";
      };
    };
}

{ interfaceName, ipAddress, extraGroups ? [], lib, ... }:

let
  users = import ../users.nix;
in

{
  imports = [
    ./common-configuration.nix
    ./ssh-server.nix
    (import ./static-network.nix { inherit interfaceName ipAddress; })
  ];

  users.users.${users.mainUser}.extraGroups = lib.toList extraGroups;
}

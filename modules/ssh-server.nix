{ ... }:

let
  users = import ../users.nix;
in

{
  imports = [
    ./hardened-ssh.nix
  ];

  users.users.${users.mainUser}.openssh.authorizedKeys.keyFiles = [
    ../ssh-keys/id_yubikey_usbc.pub
    ../ssh-keys/id_yubikey_usba.pub
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];
}

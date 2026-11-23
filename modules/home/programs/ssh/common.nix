{ ... }:

{
  programs.ssh = {
    enable = true;
  
    matchBlocks = {

      # Hosts

      "github.com" = {
        identityFile = "~/.ssh/id_ed25519_github";
        identitiesOnly = true;
      };
    };
  };
}

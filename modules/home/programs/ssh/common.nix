{ ... }:

{
  programs.ssh = {
    enable = true;
  
    matchBlocks = {

      # Options
      "*" = {
        extraOptions = {
          StrictHostKeyChecking = "yes";
        };
      };

      # Hosts
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519_github";
        identitiesOnly = true;
      };
    };
  };
}

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
        identityFile = "~/.ssh/id_github";
        identitiesOnly = true;
      };
    };
  };
}

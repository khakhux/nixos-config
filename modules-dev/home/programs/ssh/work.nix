{ users, ... }:

{
  programs.ssh.matchBlocks = {
    "gitlab.central.sepg.minhac.age" = {
      user = users.gitUser;
      identityFile = "~/.ssh/gitlab_ed25519";
      identitiesOnly = true;
    };
  };
}

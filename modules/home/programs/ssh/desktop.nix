{ users, ... }:

{
  programs.ssh.matchBlocks = {

    "raspberry42" = {
      hostname = "192.168.1.243";
      user = "pi";
      identityFile = "~/.ssh/id_yubikey_usba";
    };

    # hay que incluirlo en authorized keys
    "raspberry42c" = {
      hostname = "192.168.1.243";
      user = "pi";
      identityFile = "~/.ssh/id_yubikey_usbc";
    };

    "mininas" = {
      hostname = "192.168.1.249";
      user = users.mainUser;
      identityFile = "~/.ssh/id_yubikey_usbc";
      identitiesOnly = true;
    };

    "mininas2" = {
      hostname = "192.168.1.249";
      user = users.mainUser;
      identityFile = "~/.ssh/id_yubikey_usba";
      identitiesOnly = true;
    };

    "mininas-syncs" = {
      hostname = "192.168.1.249";
      user = "syncs";
      identityFile = "~/.ssh/id_ed25519_home";
      identitiesOnly = true;
    };
  
    "raspberry2" = {
      hostname = "192.168.1.241";
      user = "pi";
      identityFile = "~/.ssh/id_ed25519_home";
      identitiesOnly = true;
    };

    "proxmox" = {
      hostname = "192.168.1.244";
      user = users.mainUser;
      identityFile = "~/.ssh/id_ed25519_home";
      identitiesOnly = true;
    };
  };
}

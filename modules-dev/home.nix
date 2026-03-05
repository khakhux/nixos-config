{ config, pkgs, envFilePath, ... }:

let
  metodologiaRepo = pkgs.fetchgit {
    url = "git@gitlab.central.sepg.minhac.age:div_4/administracion-digital/firma-electronica/metodologia/metodologia.git";
    rev = "master"; #"61841ca3b665c3e667b3a4bdac03db8217de5fb3";  # specific commit hash
    sha256 = "sha256-eNWSqXz54TZQAzLobmRiLqSYYkDtsCf2ArHsNS/ndHc=";
  };
  envs = import envFilePath;
  mainUser = envs.mainUser; 
in
{
  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";
  home.stateVersion = "25.05";

  # Environment variables for SOPS
  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    SOPS_CONFIG = "$HOME/workspaces/.sops.yaml";
    PATH = "$HOME/workspaces/sops:$PATH";
  };
  programs.bash = {
    enable = true;
    shellAliases = { 
      hello = "echo Hello, ${mainUser}!";
      idea-java21 = "cd /workspaces/nixos-config/dev-envs/java21 && nix develop --command idea";
    };
    initExtra = ''
      nrs() {
        local host=$(hostname)
        sudo nixos-rebuild switch --flake ~/workspaces/nixos-config#"$host"
      }
    '';
  };

  programs.git = {
    enable = true;
    userName = envs.gitUser;
    userEmail = envs.gitEmail;
    extraConfig = {
      pull.rebase = false;
      init.defaultBranch = "main";
      http.sslCAInfo = "${config.home.homeDirectory}/.config/nixos-cacerts/ca-bundle.crt";
      core.attributesFile = "${config.home.homeDirectory}/.gitattributes";
      include.path = "${config.home.homeDirectory}/.config/git/firma-git-config";
    };
    aliases = {
      # mixed: unstages the changes but keeps them in your working directory
      # other options: soft, hard
      undoco = "reset HEAD~1 --mixed";
    };
  };

  home.file.".config/nixos-cacerts/ca-bundle.crt" = {
    source = pkgs.runCommand "ca-bundle.crt" {} ''
      cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > $out
      echo "" >> $out
      cat ${./cacerts/CARaiz.pem} >> $out
    '';
  };

  # Deploy SOPS configuration files
  home.file.".config/git/firma-git-config".source = ./git-config/firma-git-config;
  home.file.".gitattributes".source = ./git-config/.gitattributes;
  home.file."/workspaces/.sops.yaml".source = ./sops/.sops.yaml;
  home.file."/workspaces/sops/sops-clean.sh".source = ./sops/sops-clean.sh;
  home.file."/workspaces/sops/sops-smudge.sh".source = ./sops/sops-smudge.sh;

  # Future: Download from metodologiaRepo instead of local files
  # Uncomment when files are available in metodologia repository:
  # home.file.".config/git/sops-config".source = "${metodologiaRepo}/firma-git-config";
  # home.file.".gitattributes".source = "${metodologiaRepo}/.gitattributes";
  # home.file."/workspaces/.sops.yaml".source = "${metodologiaRepo}/.sops.yaml";

  home.file.".m2/settings.xml".source = "${metodologiaRepo}/maven/settings.xml";
  home.file."metodologia/formatter-sgife.xml".source = "${metodologiaRepo}/formatter-sgife.xml";

  # Generate age key if it doesn't exist
  home.activation.generateAgeKey = config.lib.dag.entryAfter ["writeBoundary"] ''
    AGE_KEY_DIR="${config.home.homeDirectory}/.config/sops/age"
    AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"
    
    if [ ! -f "$AGE_KEY_FILE" ]; then
      $DRY_RUN_CMD mkdir -p "$AGE_KEY_DIR"
      $DRY_RUN_CMD chmod 700 "$AGE_KEY_DIR"
      $DRY_RUN_CMD ${pkgs.age}/bin/age-keygen -o "$AGE_KEY_FILE"
      $DRY_RUN_CMD chmod 600 "$AGE_KEY_FILE"
      echo "Age key generated at $AGE_KEY_FILE"
      echo "Your public key is:"
      $DRY_RUN_CMD ${pkgs.age}/bin/age-keygen -y "$AGE_KEY_FILE"
      echo "Add this public key to .sops.yaml in your repositories"
    fi
  '';
}

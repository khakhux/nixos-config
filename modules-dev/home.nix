{ config, pkgs, envFilePath, ... }:

let
  metodologiaRepo = pkgs.fetchgit {
    url = "git@gitlab.central.sepg.minhac.age:div_4/administracion-digital/firma-electronica/metodologia/metodologia.git";
    rev = "b3f4e9818805c61e0f1f8bed0789498f73d71ada";
    # nix run nixpkgs#nix-prefetch-git -- $url --rev $rev | grep hash
    sha256 = "sha256-u37kcnylxn47xDUTC1ptfAb4++4/ygmXqLXlvxTlCUs=";
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
    SOPS_CONFIG = "$HOME/.config/sops/.sops.yaml";
    PATH = "$HOME/.config/sops:$PATH";
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
      core.attributesFile = "${config.home.homeDirectory}/.config/git/.gitattributes";
      include.path = "${config.home.homeDirectory}/.config/git/firma-git-config";
      core.excludesFile = "${config.home.homeDirectory}/.config/git/.gitignore";
    };
    aliases = {
      # mixed: unstages the changes but keeps them in your working directory
      # other options: soft, hard
      undoco = "reset HEAD~1 --mixed"; # undo last commit but keep changes staged
      editco = "git commit --amend"; # edit the last commit message
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.file.".config/nixos-cacerts/ca-bundle.crt" = {
    source = pkgs.runCommand "ca-bundle.crt" {} ''
      cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > $out
      echo "" >> $out
      cat ${./cacerts/CARaiz.pem} >> $out
    '';
  };

  home.file.".m2/settings.xml".source = "${metodologiaRepo}/maven/settings.xml";
  home.file."metodologia/formatter-sgife.xml".source = "${metodologiaRepo}/formatter-sgife.xml";

  home.file."/.config/git/firma-git-config".source = "${metodologiaRepo}/git-config/firma-git-config";
  #home.file."/.config/git/.gitattributes".source = ./git-config/.gitattributes;
  home.file."/.config/git/.gitattributes".source = "${metodologiaRepo}/git-config/.gitattributes";
  home.file."/.config/git/.gitignore".source = "${metodologiaRepo}/git-config/.gitignore";
  home.file."/.config/sops/.sops.yaml".source = "${metodologiaRepo}/sops/.sops.yaml";
  #home.file."/.config/sops/sops-clean.sh".source = ./sops/sops-clean.sh;
  home.file."/.config/sops/sops-clean.sh" = {
    source = "${metodologiaRepo}/sops/sops-clean.sh";
    executable = true;
  };
  #home.file."/.config/sops/sops-smudge.sh".source = ./sops/sops-smudge.sh;
  home.file."/.config/sops/sops-smudge.sh" = {
    source = "${metodologiaRepo}/sops/sops-smudge.sh";
    executable = true;
  };
    home.file."/.config/sops/test-sops-yaml.sh" = {
    source = "${metodologiaRepo}/sops/test-sops-yaml.sh";
    executable = true;
  };
  home.file."/.config/sops/test-sops-properties.sh" = {
    source = "${metodologiaRepo}/sops/test-sops-properties.sh";
    executable = true;
  };

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

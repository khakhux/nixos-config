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
    COMPOSE_BAKE = "true";  # docker compose build optimizations

    # Stable symlink paths created by the dev-envs/java21 shellHook.
    # These are picked up by JetBrains Gateway when it launches the WSL2
    # backend via a login shell, so IntelliJ finds the correct JDK and Maven
    # without requiring the Nix dev shell to be active.
    JAVA_HOME = "$HOME/.jdks/java21-pinned";
    M2_HOME   = "$HOME/.m2/maven-pinned";

    # JVM options file for IntelliJ IDEA (both local and Gateway backend).
    # IDEA_VM_OPTIONS overrides the IDE's own idea64.vmoptions, so these
    # settings apply regardless of which IntelliJ version Gateway downloads.
    IDEA_VM_OPTIONS = "$HOME/.config/idea/idea64.vmoptions";
  };
  programs.bash = {
    enable = true;
    shellAliases = { 
      hello = "echo Hello, ${mainUser}!";

      # Run IntelliJ IDEA inside the pinned Nix dev shell (Community edition).
      # This is the local/fallback mode; prefer JetBrains Gateway for WSL2.
      idea-java21 = "cd ~/workspaces/nixos-config/dev-envs/java21 && nix develop --command idea";

      # One-time bootstrap: enter the dev shell to create the stable symlinks
      # (~/.jdks/java21-pinned and ~/.m2/maven-pinned) that JetBrains Gateway
      # and the JAVA_HOME/M2_HOME session variables rely on.
      idea-gateway-bootstrap = "cd ~/workspaces/nixos-config/dev-envs/java21 && nix develop --command bash -c 'echo Symlinks created: && ls -la ~/.jdks/java21-pinned ~/.m2/maven-pinned'";
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

  # JVM options picked up by IntelliJ IDEA via IDEA_VM_OPTIONS (see home.sessionVariables).
  # Tuned for running as a JetBrains Gateway backend inside WSL2:
  #   - The UI is rendered by the thin client on Windows, so no GPU/X11 needed in WSL.
  #   - Generous heap for large Java projects; G1GC balances latency and throughput.
  #   - File-watcher limit bump avoids "too many open files" on big repos.
  home.file.".config/idea/idea64.vmoptions".text = ''
    -Xms512m
    -Xmx4096m
    -XX:+UseG1GC
    -XX:SoftRefLRUPolicyMSPerMB=50
    -XX:ReservedCodeCacheSize=512m
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:-OmitStackTraceInFastThrow
    -ea
    -Dsun.io.useCanonCaches=false
    -Djava.net.preferIPv4Stack=true
    -Dsun.java2d.opengl=false
    -Dsun.java2d.xrender=false
    -Dawt.useSystemAAFontSettings=lcd
    -Dide.no.platform.update=true
  '';

  home.file.".m2/settings.xml".source = "${metodologiaRepo}/maven/settings.xml";
  home.file."metodologia/formatter-sgife.xml".source = "${metodologiaRepo}/formatter-sgife.xml";

  home.file."/.config/git/firma-git-config".source = "${metodologiaRepo}/git-config/firma-git-config";
  #home.file."/.config/git/.gitattributes".source = ./git-config/.gitattributes;
  home.file."/.config/git/.gitattributes".source = "${metodologiaRepo}/git-config/.gitattributes";
  home.file."/.config/git/.gitignore".source = "${metodologiaRepo}/git-config/.gitignore";
  home.file."/.config/sops/.sops.yaml".source = "${metodologiaRepo}/sops/.sops.yaml";
  home.file."/.config/sops/sops-clean.sh" = {
    source = ./sops/sops-clean.sh;
    executable = true;
  };
  home.file."/.config/sops/sops-smudge.sh" = {
    source = ./sops/sops-smudge.sh;
    executable = true;
  };
  home.file."/.config/sops/test-sops-yaml.sh" = {
    source = ./sops/test-sops-yaml.sh;
    executable = true;
  };
  home.file."/.config/sops/test-sops-properties.sh" = {
    source = ./sops/test-sops-properties.sh;
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

{
  description = "Java Maven development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-maven398.url = "github:NixOS/nixpkgs/faaba6117872cdfbe8f6cdd25a26dd7e422f9614";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-maven398 }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system; 
        config.allowUnfree = true; 
      };
      
      # Import IntelliJ IDEA from unstable
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      
      # Use JDK 21.0.13 from the locked nixpkgs-unstable input
      jdk21-base = pkgs-unstable.jdk21;
      corporateRootCa = ../../modules-dev/cacerts/CARaiz.pem;
      fnmtIntermediateCa = ../../modules-dev/cacerts/ACCOMP.crt;
      fnmtRaizCa = ../../modules-dev/cacerts/AC-RAIZ-FNMT-RCM-SERVIDORES-SEGUROS-G2R.crt;

      jdk21-pinned = pkgs.runCommand "jdk21-with-custom-ca" {
        buildInputs = [ jdk21-base ];
        meta = jdk21-base.meta;
      } ''
        cp -r ${jdk21-base} $out
        chmod -R +w $out

        while IFS= read -r -d "" nativeLibrary; do
          ln -sfn "${jdk21-base}/''${nativeLibrary#"$out/"}" "$nativeLibrary"
        done < <(find "$out/lib/openjdk" -type f -name '*.so' -print0)

        ${jdk21-base}/bin/keytool -importcert -trustcacerts \
          -alias corporate-ca-raiz \
          -file ${corporateRootCa} \
          -keystore $out/lib/openjdk/lib/security/cacerts \
          -storepass changeit \
          -noprompt

        ${jdk21-base}/bin/keytool -importcert -trustcacerts \
          -alias fnmt-ac-componentes-informaticos \
          -file ${fnmtIntermediateCa} \
          -keystore $out/lib/openjdk/lib/security/cacerts \
          -storepass changeit \
          -noprompt

        ${jdk21-base}/bin/keytool -importcert -trustcacerts \
          -alias fnmt-raiz \
          -file ${fnmtRaizCa} \
          -keystore $out/lib/openjdk/lib/security/cacerts \
          -storepass changeit \
          -noprompt

        chmod -R -w $out
      '';
      
      # Import Maven 3.9.8 from its nixpkgs commit and use the pinned JDK 21
      pkgs-maven398 = import nixpkgs-maven398 {
        inherit system; 
        config.allowUnfree = true; 
      };
      maven398-jdk21 = pkgs-maven398.maven.override {
        jdk = jdk21-pinned; 
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "java-maven-dev";
        
        buildInputs = [
          jdk21-pinned
          maven398-jdk21
          pkgs-unstable.jetbrains.idea
          pkgs.nodejs # para sonar
        ];
        
        shellHook = ''
          # Create stable symlinks for IntelliJ IDEA
          mkdir -p ~/.jdks
          mkdir -p ~/.m2
          mkdir -p ~/.local/share/jetbrains
          mkdir -p ~/.config/nixos-cacerts
          
          # Link JDK 21 to a stable path (point to lib/openjdk for IntelliJ)
          ln -sfn ${jdk21-pinned}/lib/openjdk ~/.jdks/java21-pinned
          
          # Link Maven 3.9.8 to a stable path
          ln -sfn ${maven398-jdk21} ~/.m2/maven-pinned

          # Link IntelliJ IDEA to a stable path and expose it as IDEA_HOME
          ln -sfn ${pkgs-unstable.jetbrains.idea} ~/.local/share/jetbrains/idea-pinned
          export IDEA_HOME="$HOME/.local/share/jetbrains/idea-pinned"
                  
          echo "Java Development Environment"
          echo "=============================="
          java -version
          echo ""
          mvn -version
          echo ""
          echo "Environment variables:"
          echo "JAVA_HOME: $JAVA_HOME"
          echo "IDEA_HOME: $IDEA_HOME"
          echo ""
          echo "Stable paths created for IntelliJ IDEA:"
          echo "  JDK:   ~/.jdks/java21-pinned"
          echo "  Maven: ~/.m2/maven-pinned"
          echo "  IDEA:  ~/.local/share/jetbrains/idea-pinned"
          echo ""
          echo "IntelliJ IDEA — configuration:"
          echo "  File → Project Structure → SDKs → Add JDK"
          echo "    Path: $HOME/.jdks/java21-pinned"
          echo "  File → Settings → Build, Execution, Deployment → Build Tools → Maven"
          echo "    Maven home: $HOME/.m2/maven-pinned"
          echo ""
          echo "JetBrains Gateway (WSL2) workflow:"
          echo "  1. Run 'idea-gateway-bootstrap' once to materialise the stable symlinks"
          echo "  2. Open Gateway on Windows → Remote Development → WSL"
          echo "  3. Select this WSL distro, choose the project directory, click Start IDE"
          echo "  4. Gateway downloads + runs the IntelliJ backend inside WSL2"
          echo "  5. JAVA_HOME/M2_HOME are read from ~/.profile (set by home-manager)"
          echo "  6. Configure SDKs/Maven in IntelliJ using the stable paths above"
          echo ""
          echo "Local fallback (runs Nix-packaged IDEA directly):"
          echo "  idea"
        '';
        
        JAVA_HOME = "${jdk21-pinned}";
        M2_HOME = "${maven398-jdk21}";
        WORKSPACES = "/workspaces/nixos-config/dev-envs/java21/workspaces-java/";
      };
    };
}

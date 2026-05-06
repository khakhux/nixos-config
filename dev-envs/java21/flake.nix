{
  description = "Java Maven development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-jdk2102.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-maven386.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-jdk2102, nixpkgs-maven386 }:
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
      
      # Import pinned JDK 21 from nixos-24.05
      pkgs-jdk2102 = import nixpkgs-jdk2102 { 
        inherit system; 
        config.allowUnfree = true; 
      };
      jdk21-pinned = pkgs-jdk2102.jdk21;
      
      # Import Maven 3.8.6 from nixos-22.11 and override to use pinned JDK 21
      pkgs-maven386 = import nixpkgs-maven386 { 
        inherit system; 
        config.allowUnfree = true; 
      };
      maven386-jdk21 = pkgs-maven386.maven.override { 
        jdk = jdk21-pinned; 
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "java-maven-dev";
        
        buildInputs = [
          jdk21-pinned
          maven386-jdk21
          pkgs-unstable.jetbrains.idea
          pkgs.nodejs # para sonar
        ];
        
        shellHook = ''
          # Create stable symlinks for IntelliJ IDEA
          mkdir -p ~/.jdks
          mkdir -p ~/.m2
          mkdir -p ~/.config/nixos-cacerts
          
          # Link JDK 21.0.3 to a stable path (point to lib/openjdk for IntelliJ)
          ln -sfn ${jdk21-pinned}/lib/openjdk ~/.jdks/java21-pinned
          
          # Link Maven 3.8.6 to a stable path
          ln -sfn ${maven386-jdk21} ~/.m2/maven-pinned
                  
          echo "Java Development Environment"
          echo "=============================="
          java -version
          echo ""
          mvn -version
          echo ""
          echo "Environment variables:"
          echo "JAVA_HOME: $JAVA_HOME"
          echo ""
          echo "Stable paths created for IntelliJ IDEA:"
          echo "  JDK:   ~/.jdks/java21-pinned"
          echo "  Maven: ~/.m2/maven-pinned"
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
        M2_HOME = "${maven386-jdk21}";
      };
    };
}

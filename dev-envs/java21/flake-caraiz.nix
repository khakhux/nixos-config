{
  description = "Java Maven development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-jdk2102.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-maven386.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs, nixpkgs-jdk2102, nixpkgs-maven386 }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system; 
        config.allowUnfree = true; 
      };
      
      # Import pinned JDK 21 from nixos-24.05
      pkgs-jdk2102 = import nixpkgs-jdk2102 { 
        inherit system; 
        config.allowUnfree = true; 
      };
      jdk21-base = pkgs-jdk2102.jdk21;
      
      # Create a custom JDK with corporate CA certificate
      jdk21-pinned = pkgs.runCommand "jdk21-with-custom-ca" {
        buildInputs = [ jdk21-base ];
      } ''
        # Copy the entire JDK
        cp -r ${jdk21-base} $out
        chmod -R +w $out
        
        # Import the corporate certificate into cacerts
        ${jdk21-base}/bin/keytool -importcert -trustcacerts \
          -alias corporate-ca-raiz \
          -file ${../../modules-dev/cacerts/CARaiz.pem} \
          -keystore $out/lib/openjdk/lib/security/cacerts \
          -storepass changeit \
          -noprompt
        
        chmod -R -w $out
      '';
      
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
          pkgs.jetbrains.idea-ultimate
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
          echo "IDEA_JDK: $IDEA_JDK (IntelliJ will use this JDK to run)"
          echo ""
          echo "Stable paths created for IntelliJ IDEA:"
          echo "  JDK:   ~/.jdks/java21-pinned"
          echo "  Maven: ~/.m2/maven-pinned"
          echo ""
          echo "To configure IntelliJ IDEA:"
          echo "  1. File → Project Structure → SDKs → Add JDK"
          echo "     Path: $HOME/.jdks/java21-pinned"
          echo "  2. File → Settings → Build Tools → Maven"
          echo "     Maven home: $HOME/.m2/maven-pinned"
          echo ""
          echo "IntelliJ IDEA will run using JDK with corporate certificate."
          echo ""
          echo "To launch IntelliJ IDEA:"
          echo "  idea-ultimate"
        '';
        
        JAVA_HOME = "${jdk21-pinned}";
        M2_HOME = "${maven386-jdk21}";
      };
    };
}

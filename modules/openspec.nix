{ pkgs, pkgsUnstable, ... }:

{
  programs.bash.enableCompletion = true;

  environment.systemPackages = [
    pkgsUnstable.openspec
  ];

  environment.etc."bash_completion.d/openspec".source = pkgs.runCommand "openspec-bash-completion" {} ''
    ${pkgsUnstable.openspec}/bin/openspec completion generate bash > "$out"
  '';
}
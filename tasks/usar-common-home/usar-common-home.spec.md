Los equipos de casa usan modules/common-home.nix y modules/git.nix

currolaptop usa modules-dev/home.nix (incluye config git)

Sería interesante que modules-dev/home.nix importe de modules/common-home.nix quitando del primero lo repetido.
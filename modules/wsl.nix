{ config, pkgs, mainUser, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = mainUser;
}

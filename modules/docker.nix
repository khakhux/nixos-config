{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
  ];

  environment.variables = {
    COMPOSE_BAKE = "true"; # docker compose build optimizations
  };
}
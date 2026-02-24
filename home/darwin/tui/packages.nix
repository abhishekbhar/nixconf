{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tmux
    podman
    dive # look into docker image layers
    podman-compose # start group of containers for dev
  ];
}

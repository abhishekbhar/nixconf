{
  pkgs,
  lib,
  ...
}: {
  virtualisation = {
    containers.enable = true;
    podman.enable = lib.mkForce false;
    docker = {
      enable = true;
      daemon.settings = {
        "features" = { "containerd-snapshotter" = true; };
      };


      enableOnBoot = true;
    };
  };

  environment.systemPackages = with pkgs; [
    qemu_kvm
    qemu
    docker-compose
    dive
    lazydocker
  ];
}

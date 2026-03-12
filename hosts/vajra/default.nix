# Host: vajra (NixOS laptop, x86_64-linux)
# Home-manager configuration for vajra
_: {
  imports = [
    ../../modules
    ../../modules/platforms/linux.nix
  ];

<<<<<<< Updated upstream
  # vajra-specific home-manager overrides
  services.ttyd.enable = false;
=======
#  systemd.user.services.ttyd.enable = false;

  # vajra-specific home-manager overrides can go here
  # e.g. extra packages, GUI apps, shell config, etc.
>>>>>>> Stashed changes
}

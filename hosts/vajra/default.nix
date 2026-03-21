# Host: vajra (NixOS laptop, x86_64-linux)
# Home-manager configuration for vajra
_: {
  imports = [
    ../../modules
    ../../modules/platforms/linux.nix
  ];

  # vajra-specific home-manager overrides
  services.ttyd.enable = true;
}

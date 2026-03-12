# Host: wsl (NixOS-WSL, x86_64-linux)
# Home-manager configuration for WSL
_: {
  imports = [
    ../../modules
    ../../modules/platforms/linux.nix
  ];

  # WSL-specific home-manager overrides can go here
  # e.g. extra packages, shell config, etc.
}

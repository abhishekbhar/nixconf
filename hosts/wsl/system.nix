# Host: wsl - NixOS system configuration
{
  pkgs,
  vars,
  ...
}:
{
  imports = [
    ./virtualisation.nix
  ];

  users.users.${vars.os_user} = {
    isNormalUser = true;
    createHome = true;
    home = "/home/${vars.os_user}";
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.nushell;
  };

  environment.systemPackages = with pkgs; [
    home-manager
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc # GCC C++ runtime
    zlib # Needed by many python wheels
  ];

  wsl.enable = true;
  wsl.defaultUser = vars.os_user;
  networking.hostName = "wsl";

  system.stateVersion = "24.11";
}

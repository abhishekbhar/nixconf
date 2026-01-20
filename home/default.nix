{ vars, pkgs, ... }:
let
  # Pick the correct home directory depending on the platform
  homeDirectory =
    if pkgs.stdenv.isDarwin then
      "/Users/${vars.os_user}"
    else
      "/home/${vars.os_user}";
in
{
  imports = [ ./tui ./gui ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  home = {
    username = vars.os_user;
    inherit homeDirectory;
    sessionVariables = {
      backupFileExtention = "hm-bk";
      EDITOR = "nvim";
      TERM = "xterm-256color";
    };
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}

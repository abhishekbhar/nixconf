{ vars, ... }: {
  imports = [./tui ./gui];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  home = {
    username = vars.os_user;
    homeDirectory = "/home/${vars.os_user}";
    sessionVariables = {
      backupFileExtention = "hm-bk";
      EDITOR = "nvim";
      TERM = "xterm-256color";
    };
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}

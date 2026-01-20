{ vars, ... }:
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = vars.os_user;

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    stateVersion = "24.11";

    sessionVariables = {
      # Shell
      EDITOR = "hx";
      TERM = "xterm-256color";
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  programs.home-manager.enable = true;
}
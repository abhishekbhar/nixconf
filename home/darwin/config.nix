{
  lib,
  vars,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/Users/${vars.os_user}";

  # enable management of XDG base directories on macOS.
  # xdg.enable = true;
}

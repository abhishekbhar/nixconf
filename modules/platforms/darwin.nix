{
  lib,
  vars,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/Users/${vars.os_user}";
}

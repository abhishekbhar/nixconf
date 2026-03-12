{
  config,
  lib,
  pkgs,
  mostlatestpkgs,
  vars,
  ...
}:
{
  programs.claude-code = {
    enable = true;
    package = mostlatestpkgs.claude-code;
  };
}

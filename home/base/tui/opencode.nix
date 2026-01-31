{ config, pkgs, ... }:
{
  # Ensure you have enabled opencode module
  programs.opencode.enable = true;

  # Optionally, Configure settings (like theme or model)
  programs.opencode.settings = {
    theme = "opencode";
    plugin = [ ];
  };
}

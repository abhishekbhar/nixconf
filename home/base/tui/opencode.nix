{
  config,
  pkgs,
  mostlatestpkgs,
  ...
}:
{
  # Ensure you have enabled opencode module
  programs.opencode.enable = true;

  # Use opencode from mostlatestpkgs (nixpkgs master) for latest version
  programs.opencode.package = mostlatestpkgs.opencode;

  # Optionally, Configure settings (like theme or model)
  programs.opencode.settings = {
    theme = "opencode";
    plugin = [ ];
  };
}

{
  config,
  lib,
  vars,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/Users/${vars.os_user}";

  programs.ssh.matchBlocks."github.com" = {
    hostname = "github.com";
    identityFile = vars.git_ssh_identity_file;
    addKeysToAgent = "yes";
    extraOptions = {
      UseKeychain = "yes";
    };
  };
}

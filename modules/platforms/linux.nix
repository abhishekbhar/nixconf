{
  config,
  lib,
  vars,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/home/${vars.os_user}";

  home.sessionVariables = {
    backupFileExtension = "hm-bk";
    NIX_SSL_CERT_FILE = vars.ssl_cert_path;
  };

  programs.ssh.matchBlocks."github.com" = {
    hostname = "github.com";
    identityFile = vars.git_ssh_identity_file;
    addKeysToAgent = "yes";
  };

  programs.ssh.matchBlocks."git.abhibhr.in" = {
    hostname = "git.abhibhr.in";
    port = 2222;
    user = "git";
    identityFile = vars.git_ssh_identity_file;
  };
}

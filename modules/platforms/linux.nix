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
}

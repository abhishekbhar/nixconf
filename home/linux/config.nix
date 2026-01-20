{
  lib,
  vars,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/home/${vars.os_user}";

  # Linux-specific session variables
  home.sessionVariables = {
    # Linux specific environment
    backupFileExtension = "hm-bk";
    NIX_SSL_CERT_FILE = vars.ssl_cert_path;
  };
}

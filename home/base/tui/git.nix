{
  config,
  lib,
  pkgs,
  vars,
  ...
}: {
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] "rm -f ${config.home.homeDirectory}/.gitconfig";

  home.packages = with pkgs; [ lazygit ];

  programs.git = {
    enable = true;
    lfs.enable = true;

    userName = vars.vcs_user;
    userEmail = vars.vcs_email;

    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      safe.directory = "*";
    };
  };
}

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

    settings = {
      user = {
        name = vars.vcs_user;
        email = vars.vcs_email;
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      safe.directory = "*";
    };
  };

  # SSH configuration for git operations
  programs.ssh.matchBlocks."github.com" = {
    hostname = "github.com";
    identityFile = vars.git_ssh_identity_file;
    addKeysToAgent = "yes";
    extraOptions = {
      UseKeychain = "yes";
    };
  };
}

{ pkgs, pkgs-latest, vars, ... }: {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./git.nix
    ./helix.nix
    ./jj.nix
    ./shell.nix
    ./starship.nix
    ./yazi.nix
    ./opencode.nix
  ];

  home.packages = with pkgs; [
    fd
    btop
    gnumake
    git-crypt
    tldr
    unzip
    ripgrep
    nil
    nixd
    nixfmt-rfc-style
    glow
    nerd-fonts.fira-code
    gcc
    gdu
    zellij
    gomatrix
    awscli2
    duf
    devenv
  ] ++ ( with pkgs-latest; []);

  fonts = { fontconfig.enable = true; };

  programs = {
    fzf = {
      enable = true;
      colors = {
        "bg+" = "#313244";
        "bg" = "#1e1e2e";
        "spinner" = "#f5e0dc";
        "hl" = "#f38ba8";
        "fg" = "#cdd6f4";
        "header" = "#f38ba8";
        "info" = "#cba6f7";
        "pointer" = "#f5e0dc";
        "marker" = "#f5e0dc";
	"fg+" = "#cdd6f4";
	"prompt" = "#cba6f7";
	"hl+" = "#f38ba8";
      };
    };
   
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      settings = {
        style = "full";
      };
    };
   
    carapace = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
} 

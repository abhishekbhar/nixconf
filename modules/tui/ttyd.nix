{
  config,
  pkgs,
  lib,
  ...
}:

let
  ttyd-port = "2828";
in
{
  home.packages = with pkgs; [ ttyd ];

  launchd.agents.ttyd = {
    enable = true;
    config = {
      EnvironmentVariables = {
        HOME = "${config.home.homeDirectory}";
        TERM = "xterm-256color";
        ZELLIJ_CONFIG_DIR = "${config.home.homeDirectory}/.config/zellij";
        SHELL = "${pkgs.zsh}/bin/zsh";
      };
      ProgramArguments = [
        "${pkgs.ttyd}/bin/ttyd"
        "-p"
        ttyd-port
        "-W"
        "zsh"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/ttyd.out.log";
      StandardErrorPath = "/tmp/ttyd.err.log";
    };
  };

  systemd.user.services.ttyd = {
    enable = true;
    description = "ttyd - terminal over HTTP";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "TERM=xterm-256color"
        "ZELLIJ_CONFIG_DIR=${config.home.homeDirectory}/.config/zellij"
        "SHELL=${pkgs.zsh}/bin/zsh"
      ];
      ExecStart = "${pkgs.ttyd}/bin/ttyd -p ${ttyd-port} -W zsh";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}

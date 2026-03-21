{
  config,
  pkgs,
  lib,
  ...
}:

let
  ttyd-port = "2828";
  zellij-attach = pkgs.writeShellScript "zellij-attach" ''
    export HOME="${config.home.homeDirectory}"
    export TERM="xterm-256color"
    export ZELLIJ_CONFIG_DIR="${config.home.homeDirectory}/.config/zellij"
    export SHELL="${pkgs.zsh}/bin/zsh"
    exec ${pkgs.zellij}/bin/zellij attach Remote-Work --create
  '';
in
{
  options.services.ttyd.enable = lib.mkEnableOption "ttyd terminal over HTTP";

  config = lib.mkIf config.services.ttyd.enable {
    home.packages = with pkgs; [ ttyd ];

    launchd.agents.ttyd = lib.mkIf pkgs.stdenv.isDarwin {
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
          "${zellij-attach}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/ttyd.out.log";
        StandardErrorPath = "/tmp/ttyd.err.log";
      };
    };

    systemd.user.services.ttyd = lib.mkIf pkgs.stdenv.isLinux {
      Unit.Description = "ttyd - terminal over HTTP";
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "TERM=xterm-256color"
          "ZELLIJ_CONFIG_DIR=${config.home.homeDirectory}/.config/zellij"
          "SHELL=${pkgs.zsh}/bin/zsh"
        ];
        ExecStart = "${pkgs.ttyd}/bin/ttyd -p ${ttyd-port} -W ${zellij-attach}";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}

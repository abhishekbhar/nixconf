{ pkgs, ... }:

let
  ttyd-port = "2828";
in
{
  home.packages = with pkgs; [ ttyd ];

  launchd.agents.ttyd = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.ttyd}/bin/ttyd"
        "-p"
        ttyd-port
        "${pkgs.zellij}/bin/zellij"
        "run"
        "--close-on-exit"
        "-c"
        "${pkgs.nushell}/bin/nu"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/ttyd.out.log";
      StandardErrorPath = "/tmp/ttyd.err.log";
    };
  };
}

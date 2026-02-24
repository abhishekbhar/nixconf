{ vars, lib, ... }:
{
  home.sessionVariables = {
    TRILIUM_API_URL = vars.trilium_api_url;
    TRILIUM_ETAPI_TOKEN = vars.trilium_etapi_token;
  };

  home.file."Library/LaunchAgents/user.env.trillium-api-url.plist" = {
    text = lib.generators.toPlist { } {
      Label = "user.env.trillium-api-url";
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "TRILIUM_API_URL"
        vars.trilium_api_url
      ];
      RunAtLoad = true;
    };
  };

  home.file."Library/LaunchAgents/user.env.trillium-etapi-token.plist" = {
    text = lib.generators.toPlist { } {
      Label = "user.env.trillium-etapi-token";
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "TRILLIUM_ETAPI_TOKEN"
        vars.trilium_etapi_token
      ];
      RunAtLoad = true;
    };
  };
}

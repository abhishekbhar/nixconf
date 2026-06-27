# Dev container systemd service — replaces Coder workspaces.
#
# Multi-developer: each developer gets their own systemd service.
# Enable by listing their short names in services.devbox.users.
#
# Usage in hosts/vajra/system.nix:
#   imports = [ ../../modules/nixos/devbox.nix ];
#   services.devbox = {
#     enable = true;
#     users  = [ "abhishek" "jane" ];   # one container per user
#   };
#
# Disable Coder at the same time:
#   imports = [
#     # ./coder.nix        # comment out
#     ../../modules/nixos/devbox.nix
#   ];
#   services.devbox = {
#     enable = true;
#     users  = [ "abhishek" ];
#   };
#
# Each user needs:
#   devcontainer/.env.<name>  with their TS_AUTH_KEY
# Create via:  make devbox-add <name>

{ config, lib, pkgs, ... }:
let
  cfg = config.services.devbox;
  composeDir = "/home/abhishekbhar/nixconf/devcontainer";
  composeFile = "${composeDir}/docker-compose.yml";
in
{
  options.services.devbox = {
    enable = lib.mkEnableOption "Dev containers (Tailscale SSH)";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "abhishek" ];
      description = ''
        List of developer short names. Each gets a systemd service
        that runs `docker compose -p devbox-<name> up` on boot.
        Each must have a corresponding devcontainer/.env.<name> file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = lib.listToAttrs (map (user: {
      name = "devbox-${user}";
      value = {
        description = "Dev container for ${user} (Tailscale SSH)";
        after = [ "docker.service" "network-online.target" "tailscaled.service" ];
        wants = [ "docker.service" "network-online.target" "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];

        path = with pkgs; [ docker docker-compose ];

        preStart = ''
          # Ensure .env file exists (create from example if missing)
          env_file="${composeDir}/.env.${user}"
          if [ ! -f "$env_file" ]; then
            if [ -f "${composeDir}/.env.example" ]; then
              cp "${composeDir}/.env.example" "$env_file"
              echo "  ⚠ Created $env_file — set TS_AUTH_KEY before first boot"
            fi
          fi
        '';

        serviceConfig = {
          Type = "simple";
          WorkingDirectory = composeDir;
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} --env-file .env.${user} -p devbox-${user} up";
          ExecStop  = "${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} --env-file .env.${user} -p devbox-${user} down";
          Restart = "on-failure";
          RestartSec = 10;
          TimeoutStartSec = 120;
        };
      };
    }) cfg.users);
  };
}

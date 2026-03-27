# Paperclip AI - AI agent orchestration platform
# Runs via Docker Compose managed by a systemd service
{ pkgs, ... }:
let
  composeFile = pkgs.writeText "docker-compose-paperclip.yml" ''
    services:
      db:
        image: postgres:17-alpine
        restart: unless-stopped
        environment:
          POSTGRES_USER: paperclip
          POSTGRES_PASSWORD: paperclip
          POSTGRES_DB: paperclip
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U paperclip -d paperclip"]
          interval: 2s
          timeout: 5s
          retries: 30
        volumes:
          - pgdata:/var/lib/postgresql/data

      server:
        build:
          context: /var/lib/paperclip/repo
          dockerfile: Dockerfile
        restart: unless-stopped
        ports:
          - "3100:3100"
        env_file:
          - /var/lib/paperclip/env
        environment:
          DATABASE_URL: postgres://paperclip:paperclip@db:5432/paperclip
          PORT: "3100"
          HOST: "0.0.0.0"
          SERVE_UI: "true"
          PAPERCLIP_DEPLOYMENT_MODE: "authenticated"
          PAPERCLIP_DEPLOYMENT_EXPOSURE: "private"
          PAPERCLIP_PUBLIC_URL: "http://192.168.11.101:3100"
          PAPERCLIP_ALLOWED_HOSTNAMES: "localhost,192.168.11.101"
          PAPERCLIP_HOME: "/paperclip"
          CLAUDE_CONFIG_DIR: "/home/node/.claude"
        volumes:
          - paperclip-data:/paperclip
          - /home/abhishekbhar/.claude:/home/node/.claude:ro
        depends_on:
          db:
            condition: service_healthy

    volumes:
      pgdata:
      paperclip-data:
  '';
in
{
  systemd.services.paperclip = {
    description = "Paperclip AI - Agent Orchestration Platform";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "docker.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ docker docker-compose git openssl ];

    preStart = ''
      # Ensure data directory exists
      mkdir -p /var/lib/paperclip

      # Generate auth secret on first run
      if [ ! -f /var/lib/paperclip/env ]; then
        echo "BETTER_AUTH_SECRET=$(openssl rand -hex 32)" > /var/lib/paperclip/env
      fi

      # Clone or update the Paperclip repo
      if [ ! -d /var/lib/paperclip/repo ]; then
        git clone https://github.com/paperclipai/paperclip.git /var/lib/paperclip/repo
      else
        git -C /var/lib/paperclip/repo pull --ff-only || true
      fi

      # Fix upstream Dockerfile: patches dir must be copied before pnpm install
      if ! grep -q 'COPY patches/' /var/lib/paperclip/repo/Dockerfile; then
        ${pkgs.gnused}/bin/sed -i 's|RUN pnpm install --frozen-lockfile|COPY patches/ patches/\nRUN pnpm install --frozen-lockfile|' /var/lib/paperclip/repo/Dockerfile
      fi
    '';

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/var/lib/paperclip";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} -p paperclip up --build";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} -p paperclip down";
      Restart = "on-failure";
      RestartSec = 10;
      StateDirectory = "paperclip";
    };
  };

  networking.firewall.allowedTCPPorts = [ 3100 ];
}

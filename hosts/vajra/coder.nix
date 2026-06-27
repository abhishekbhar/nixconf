# Coder - self-hosted remote dev environments
# Coder server + Postgres via Docker Compose, managed by a systemd service.
# State lives on /mnt/storage (2TB SSD).
# Public entry: https://coder.abhibhr.in. Workspace apps and port forwarding
# use path-based URLs (subdomain=false) since Cloudflare Free can't serve
# wildcard edge certs for *.coder.abhibhr.in.
# Traffic: Browser -> Cloudflare -> server2 NPM (192.168.11.102) -> vajra:7080.
{ pkgs, ... }:
let
  composeFile = pkgs.writeText "docker-compose-coder.yml" ''
    services:
      db:
        image: postgres:17-alpine
        restart: unless-stopped
        environment:
          POSTGRES_USER: coder
          POSTGRES_PASSWORD: coder
          POSTGRES_DB: coder
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U coder -d coder"]
          interval: 2s
          timeout: 5s
          retries: 30
        volumes:
          - /mnt/storage/coder/pgdata:/var/lib/postgresql/data

      coder:
        image: ghcr.io/coder/coder:2.33.9
        restart: unless-stopped
        # Root so the server can read /var/run/docker.sock without pinning
        # the host docker GID. Provisions workspace containers only.
        # Image pinned to 2.33.9 (Stable channel, released 2026-06-17)
        # to keep us off Mainline. See coder.nix commit history for bumps.
        user: root
        ports:
          - "7080:7080"
        environment:
          CODER_PG_CONNECTION_URL: "postgres://coder:coder@db:5432/coder?sslmode=disable"
          CODER_HTTP_ADDRESS: "0.0.0.0:7080"
          CODER_ACCESS_URL: "https://coder.abhibhr.in"
          # CODER_WILDCARD_ACCESS_URL intentionally NOT set — Cloudflare Free
          # can't serve wildcard edge certs for *.coder.abhibhr.in, so we use
          # path-based URLs for all workspace apps and port forwarding.
          CODER_DISABLE_PORT_FORWARD: "false"
          # No direct laptop<->workspace tunneling; all traffic via Coder server.
          # Necessary for the egress firewall to have any meaning.
          CODER_DISABLE_DIRECT_CONNECTIONS: "true"
          CODER_PROXY_TRUSTED_HEADERS: "X-Forwarded-For,X-Forwarded-Proto"
          CODER_PROXY_TRUSTED_ORIGINS: "192.168.11.102/32,100.87.43.112/32"
          CODER_TELEMETRY: "false"
          CODER_BLOCK_FILEDL: "true"
          # Allow path-based apps (subdomain=false) to use sharing_level
          # other than "owner" (e.g. "authenticated" for team workspaces).
          CODER_DANGEROUS_ALLOW_PATH_APP_SHARING: "true"
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - /mnt/storage/coder/data:/home/coder/.config/coderv2
        depends_on:
          db:
            condition: service_healthy
  '';
in
{
  systemd.services.coder = {
    description = "Coder - Self-hosted Remote Dev Environments";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "docker.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ docker docker-compose ];

    preStart = ''
      mkdir -p /mnt/storage/coder/pgdata
      mkdir -p /mnt/storage/coder/data
    '';

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/var/lib/coder";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} -p coder up";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} -p coder down";
      Restart = "on-failure";
      RestartSec = 10;
      StateDirectory = "coder";
    };
  };
}

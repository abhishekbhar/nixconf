# Devbox — VPS Migration Plan

> **Goal:** Move all 4 devboxes + shared infrastructure to a VPS without data
> loss and without changing Tailscale IPs.
>
> **Architecture doc:** `docker-compose.yml` + `Dockerfile` + env files in this dir.

---

## 1. Current Inventory

### 1.1 Containers

| Container | Role | Image | RAM (actual) | RAM (limit) | Restart |
|---|---|---|---|---|---|
| `devbox-abhishek` | code-server + sshd | `devbox-abhishek-devbox` | 79 MB | 8 GB | unless-stopped |
| `devbox-himanshu` | code-server + sshd | `devbox-himanshu-devbox` | 77 MB | 8 GB | unless-stopped |
| `devbox-rupam` | code-server + sshd | `devbox-rupam-devbox` | 75 MB | 8 GB | unless-stopped |
| `devbox-keshav` | code-server + sshd | `devbox-keshav-devbox` | 73 MB | 8 GB | unless-stopped |
| `ts-abhishek` | Tailscale sidecar | `tailscale/tailscale:latest` | 52 MB | — | unless-stopped |
| `ts-himanshu` | Tailscale sidecar | `tailscale/tailscale:latest` | 43 MB | — | unless-stopped |
| `ts-rupam` | Tailscale sidecar | `tailscale/tailscale:latest` | 41 MB | — | unless-stopped |
| `ts-keshav` | Tailscale sidecar | `tailscale/tailscale:latest` | 43 MB | — | unless-stopped |
| `shared-postgres` | App PostgreSQL 16 | `postgres:16` | 37 MB | — | unless-stopped |
| `shared-keycloak-pg` | Keycloak PostgreSQL 16 | `postgres:16` | 45 MB | — | unless-stopped |
| `shared-keycloak` | Keycloak 26.0 (IAM/SSO) | `quay.io/keycloak/keycloak:26.0` | 711 MB | — | unless-stopped |
| `shared-redis` | Redis 7 (cache) | `redis:7-alpine` | 15 MB | — | unless-stopped |

### 1.2 Docker Volumes (data to migrate)

| Volume | Content | Size | Type |
|---|---|---|---|
| `devbox-abhishek_devbox-home` | User home: workspace, SSH keys, git config, nix profile, pi agent, code-server | 8.0 GB | named volume |
| `devbox-himanshu_devbox-home` | Same — Himanshu | 8.0 GB | named volume |
| `devbox-rupam_devbox-home` | Same — Rupam | 8.2 GB | named volume |
| `devbox-keshav_devbox-home` | Same — Keshav | 7.8 GB | named volume |
| `devbox-abhishek_tsstate` | Tailscale machine key + IP lease | 144 KB | named volume |
| `devbox-himanshu_tsstate` | Tailscale machine key + IP lease | 156 KB | named volume |
| `devbox-rupam_tsstate` | Tailscale machine key + IP lease | 48 KB | named volume |
| `devbox-keshav_tsstate` | Tailscale machine key + IP lease | 156 KB | named volume |
| `shared-infra_shared-pgdata` | App PostgreSQL data (`algomatter_*` databases) | 111.5 MB | named volume |
| `shared-infra_shared-keycloak-pgdata` | Keycloak PostgreSQL data (realms, users) | 66.4 MB | named volume |
| `shared-infra_shared-redisdata` | Redis cache data | 8 KB | named volume |

### 1.3 Config Files (ship alongside volumes)

| File | Purpose |
|---|---|
| `docker-compose.yml` | Devbox + Tailscale sidecar compose |
| `Dockerfile` | Devbox image build |
| `scripts/entrypoint.sh` | Devbox startup script |
| `.env.abhishek` | Env vars for Abhishek's devbox |
| `.env.himanshu` | Env vars for Himanshu's devbox |
| `.env.rupam` | Env vars for Rupam's devbox |
| `.env.keshav` | Env vars for Keshav's devbox |

### 1.4 Tailscale IPs (Current)

| Node | Tailscale IP | MagicDNS |
|---|---|---|
| `devbox-abhishek-3` | `100.94.43.18` | `devbox-abhishek-3.encke-manta.ts.net` |
| `devbox-himanshu` | `100.115.205.27` | `devbox-himanshu.encke-manta.ts.net` |
| `devbox-rupam` | `100.80.68.86` | `devbox-rupam.encke-manta.ts.net` |
| `devbox-keshav` | `100.109.87.101` | `devbox-keshav.encke-manta.ts.net` |

---

## 2. Pre-Migration Checklist

### 2.1 Export Keycloak Realm ⚠️ CRITICAL

The `docker-compose.infra.yml` mounts a realm export file:
```yaml
volumes:
  - ./backend/keycloak/realm-export.json:/opt/keycloak/data/import/realm-export.json:ro
```
This path is **relative to the compose file inside a devbox workspace**. On the VPS this file won't exist unless you export and bring it.

**Procedure (run on current host):**

```bash
# Export current Keycloak realm (config, not user data — user data is in PG)
docker exec shared-keycloak /opt/keycloak/bin/kc.sh export \
  --dir /tmp/realm-export --realm algomatter

# Copy the export out of the container
docker cp shared-keycloak:/tmp/realm-export/. /tmp/keycloak-export/

# Archive it
tar czf keycloak-realm-export.tar.gz -C /tmp/keycloak-export .
```

> 💡 `kc.sh export` exports **realm configuration** (clients, roles, flows).
> **User data lives in PostgreSQL** (`shared-keycloak-pg`), which is already
> in a volume. As long as you migrate the `shared-infra_shared-keycloak-pgdata`
> volume, user accounts survive.

### 2.2 Verify Tailscale Auth Keys Are Non-Ephemeral

Current `.env` files have keys like `tskey-auth-...`. The env file comments
confirm `--ephemeral=false`. **No action needed** — state is persistent.

To verify on any running sidecar:
```bash
docker exec ts-abhishek tailscale status --self
```

### 2.3 Note Port Exposures (Security)

Shared services currently bind to `0.0.0.0` on the host:
- Postgres: `0.0.0.0:5432`
- Redis: `0.0.0.0:6379`
- Keycloak: `0.0.0.0:8180`

On your local machine this is fine behind a firewall. **On a public VPS,
bind these to `127.0.0.1`** and access only via Tailscale.

---

## 3. Migration Procedure

### Phase 1 — Backup (on current host)

```bash
# 1a. Export Keycloak realm (if you need realm config)
./phase1-export-keycloak.sh

# 1b. Backup all Docker volumes into tarballs
BACKUP_DIR=/tmp/devbox-migration
mkdir -p "$BACKUP_DIR"

for vol in \
  devbox-abhishek_devbox-home devbox-himanshu_devbox-home \
  devbox-rupam_devbox-home devbox-keshav_devbox-home \
  devbox-abhishek_tsstate devbox-himanshu_tsstate \
  devbox-rupam_tsstate devbox-keshav_tsstate \
  shared-infra_shared-pgdata shared-infra_shared-keycloak-pgdata \
  shared-infra_shared-redisdata; do
  echo "Backing up $vol..."
  docker run --rm -v "$vol":/data alpine tar czf "/data.tar.gz" -C /data . 2>/dev/null
  # Actually use a named container to get the archive out
  docker run --rm -v "$vol":/source -v "$BACKUP_DIR":/backup alpine \
    tar czf "/backup/${vol}.tar.gz" -C /source .
done

# 1c. Save devbox images
docker save devbox-abhishek-devbox devbox-himanshu-devbox \
  devbox-rupam-devbox devbox-keshav-devbox | gzip > "$BACKUP_DIR/devbox-images.tar.gz"

# 1d. Copy config files
cp -a /home/abhishekbhar/nixconf/devcontainer/ "$BACKUP_DIR/config/"

# 1e. Transfer to VPS (via rsync or scp)
rsync -avP "$BACKUP_DIR/" vps:/opt/devbox-migration/
```

### Phase 2 — Set Up VPS

```bash
# 2a. Install Docker (Ubuntu/Debian example)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 2b. Create required directories
mkdir -p /opt/devbox/config
mkdir -p /opt/devbox/data

# 2c. Restore config files
tar xzf /opt/devbox-migration/config.tar.gz -C /opt/devbox/config/

# 2d. Restore Docker volumes
cd /opt/devbox-migration
for f in *_devbox-home.tar.gz *_tsstate.tar.gz shared-infra_*.tar.gz; do
  vol_name="${f%.tar.gz}"
  echo "Restoring $vol_name..."
  docker volume create "$vol_name"
  docker run --rm -v "$vol_name":/dest -v "$(pwd)":/backup alpine \
    tar xzf "/backup/$f" -C /dest
done

# 2e. Load devbox images
gunzip -c devbox-images.tar.gz | docker load
```

### Phase 3 — Deploy Shared Infrastructure

On the VPS, shared infrastructure should be managed with a **standalone
compose file** (not depending on a devbox workspace path).

**Create `/opt/devbox/docker-compose.infra.yml`** (see Appendix A for
the cleaned-up version):

```bash
docker compose -f /opt/devbox/docker-compose.infra.yml up -d

# Verify data intact
docker exec shared-postgres psql -U algomatter -d algomatter -c '\l'
docker exec shared-keycloak-pg psql -U keycloak -d keycloak -c '\dt'
```

### Phase 4 — Deploy Devboxes

```bash
cd /opt/devbox/config

# Start each devbox (one at a time, verify after each)
for user in abhishek himanshu rupam keshav; do
  docker compose -f docker-compose.yml \
    --env-file ".env.${user}" \
    -p "devbox-${user}" up -d

  # Wait for health
  echo "Waiting for devbox-${user} to be healthy..."
  sleep 15
  docker ps --filter "name=devbox-${user}" --format "{{.Names}} {{.Status}}"
done
```

### Phase 5 — Verify Tailscale IPs

```bash
for ts in ts-abhishek ts-himanshu ts-rupam ts-keshav; do
  echo "$ts: $(docker exec $ts tailscale ip -4)"
done
```

Expected output (same IPs as before migration):
```
ts-abhishek: 100.94.43.18
ts-himanshu: 100.115.205.27
ts-rupam: 100.80.68.86
ts-keshav: 100.109.87.101
```

### Phase 6 — DNS Propagation

If any apps or team members reference devboxes by Tailscale IP, no action
needed (IPs unchanged). If using MagicDNS (`*.encke-manta.ts.net`), it
also works — the machine name is bound to the machine key in the state
volume, which was migrated.

---

## 4. Rollback Plan

If something goes wrong on the VPS:

```bash
# On current host, containers are still running (they were never stopped).
# Just verify they're still accessible:
ssh coder@devbox-abhishek

# If you already stopped them on current host, restart:
for user in abhishek himanshu rupam keshav; do
  docker compose -f /home/abhishekbhar/nixconf/devcontainer/docker-compose.yml \
    --env-file "/home/abhishekbhar/nixconf/devcontainer/.env.${user}" \
    -p "devbox-${user}" up -d
done

# Restart shared infra
docker compose -f /home/abhishekbhar/workspace/algomatter/docker-compose.infra.yml up -d
```

> ⚠️ **Do NOT delete volumes or stop containers on the current host until
> the VPS setup is fully verified.**

---

## 5. Post-Migration Cleanup

After confirming everything works on the VPS:

1. Verify all devboxes accessible via SSH + MagicDNS
2. Verify code-server accessible at `http://<ts-ip>:13337`
3. Verify shared Postgres/Redis accessible from within devboxes
4. Verify Keycloak login works
5. Update any CI/CD configs that reference the old host
6. Set up automated volume backups on the VPS
7. Stop and remove containers on the old host
8. Optionally remove old volumes (after weeks of no issues)

---

## 6. VPS Minimum Hardware Requirements

### Recommended Minimum

| Resource | Requirement | Rationale |
|---|---|---|
| **vCPU** | **8 cores** | 4 devboxes × 2 cores for real work + shared infra overhead. Devboxes are limited to 4 CPUs each but actual usage is well below that — 8 vCPUs gives headroom for bursts. |
| **RAM** | **16 GB** | Devboxes are limited to 8 GB each, but actual usage is ~80 MB. Even with 2 simultaneous builds, 16 GB is comfortable. Keycloak is the biggest idling consumer at ~700 MB. |
| **Disk** | **120 GB** | Current data: ~32 GB volumes + ~5 GB images + shared infra. 120 GB gives room for growth, package caches, nix store expansion, and Docker build cache. Prefer NVMe SSD. |
| **Bandwidth** | **1 Gbps** (unmetered or 2+ TB) | Devbox users push/pull Docker images, git repos, and may do npm/pip/nix installs. 1 Gbps ensures fast experience. |
| **Public IP** | **1 static IPv4** | Needed for Tailscale to establish direct connections. A /64 IPv6 block is a bonus. |

### Cost-Optimized Minimum

| Resource | Requirement |
|---|---|
| **vCPU** | **4 cores** (slower concurrent builds, but fine for idle/idle-ish dev usage) |
| **RAM** | **8 GB** (tight — works if devs don't run heavy builds simultaneously; disable Keycloak or allocate less heap) |
| **Disk** | **80 GB** (enough for current data + ~30 GB headroom) |

### Why Not Less?

- **4 GB RAM** is too tight — Keycloak alone uses ~700 MB, plus Postgres + Redis + Tailscale sidecars, there's not enough for a devbox with nix/node builds.
- **2 vCPUs** — fine for idle, but a `nix build` or `npm install` on one devbox will starve others.
- **40 GB disk** — current data is ~38 GB; no room for growth, Docker layers, or workspace expansion.

### Recommended Providers

| Provider | Plan | vCPU | RAM | Disk | Est. Monthly |
|---|---|---|---|---|---|
| **Hetzner** | AX42 / CX62 | 8 / 16 | 32 GB | 240+ GB NVMe | €25–40 |
| **Netcup** | RS 2000 G11 | 8 | 32 GB | 512 GB NVMe | ~€15 |
| **Contabo** (already used) | Cloud VPS L | 8 | 30 GB | 600 GB SSD | ~€10 |
| **Scaleway** | DEV-L | 8 | 32 GB | 200 GB Block | ~€30 |
| **DigitalOcean** | Basic 16 GB | 4 | 16 GB | 160 GB | $48/mo |

> **Recommendation:** Hetzner CX62 (8 vCPU, 32 GB, NVMe) or Netcup RS 2000
> for best price/performance. Contabo is already in your tailnet and may
> offer the easiest management (same provider).

### Actual Resource Usage (measured on current host)

| Component | Actual RAM | Limit |
|---|---|---|
| Per devbox (code-server + sshd + nix) | ~75–80 MB | 8 GB |
| Per Tailscale sidecar | ~41–52 MB | — |
| Keycloak (Java, idle) | ~711 MB | — |
| Postgres (app) | ~37 MB | — |
| Postgres (keycloak) | ~45 MB | — |
| Redis | ~15 MB | — |
| **Total (all containers)** | **~1.3 GB** | — |

The 8 GB limit per devbox is a **safety ceiling** for burst scenarios
(heavy nix builds, npm installs, compilers). Actual steady-state is
extremely lightweight.

### VPS Setup Recommendations

```bash
# After provisioning the VPS:

# 1. Basic hardening
ufw allow OpenSSH
ufw allow in on tailscale0  # allow everything on Tailscale
ufw default deny incoming
ufw --force enable

# 2. Docker with iptables control to prevent port exposure
#    (edit /etc/docker/daemon.json)
cat > /etc/docker/daemon.json <<'EOF'
{
  "iptables": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# 3. Change compose infra ports to 127.0.0.1 (Tailscale-only access)
#    In docker-compose.infra.yml, change:
#      ports: "5432:5432" → ports: "127.0.0.1:5432:5432"
#      ports: "6379:6379" → ports: "127.0.0.1:6379:6379"
#      ports: "8180:8080" → ports: "127.0.0.1:8180:8080"
```

---

## Appendix A: Cleaned-Up shared-infra compose for VPS

Save as `/opt/devbox/docker-compose.infra.yml`:

```yaml
name: shared-infra

services:
  postgres:
    container_name: shared-postgres
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-algomatter}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-algomatter}
      POSTGRES_DB: ${POSTGRES_DB:-algomatter}
    ports:
      - "127.0.0.1:5432:5432"      # Tailscale-only access
    volumes:
      - shared-pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-algomatter}"]
      interval: 5s
      retries: 5
    networks:
      - shared-infra-net

  redis:
    container_name: shared-redis
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"      # Tailscale-only access
    volumes:
      - shared-redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5
    networks:
      - shared-infra-net

  keycloak-postgres:
    container_name: shared-keycloak-pg
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${KC_DB_PASSWORD:-keycloak}
      POSTGRES_DB: keycloak
    volumes:
      - shared-keycloak-pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U keycloak"]
      interval: 5s
      retries: 5
    networks:
      - shared-infra-net

  keycloak:
    container_name: shared-keycloak
    image: quay.io/keycloak/keycloak:26.0
    restart: unless-stopped
    command: ["start", "--import-realm"]
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://keycloak-postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KC_DB_PASSWORD:-keycloak}
      KC_HOSTNAME: ${KC_HOSTNAME:-auth.algomatter.in}
      KC_HOSTNAME_STRICT: "false"
      KC_PROXY_HEADERS: xforwarded
      KC_HTTP_ENABLED: "true"
      KC_HEALTH_ENABLED: "true"
      KC_METRICS_ENABLED: "true"
      KC_LOG_LEVEL: INFO
      KC_FEATURES: "token-exchange"
      KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN:-admin}
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD:-admin}
      JAVA_OPTS_APPEND: "-Xms256m -Xmx512m"
    volumes:
      # Place the exported realm file at this path on the VPS
      - /opt/devbox/data/keycloak/realm-export.json:/opt/keycloak/data/import/realm-export.json:ro
    ports:
      - "127.0.0.1:8180:8080"      # Tailscale-only access
    depends_on:
      keycloak-postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "timeout 3 bash -c 'exec 3<>/dev/tcp/localhost/9000 && echo -e \"GET /health/ready HTTP/1.1\\r\\nHost: localhost\\r\\n\\r\\n\" >&3 && timeout 2 cat <&3' | grep -q UP"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 60s
    networks:
      - shared-infra-net

networks:
  shared-infra-net:
    name: shared-infra-net
    driver: bridge

volumes:
  shared-pgdata:
  shared-redisdata:
  shared-keycloak-pgdata:
```

> Key differences from current: ports bound to `127.0.0.1` instead of
> `0.0.0.0`, and realm export path is an absolute VPS path instead of
> a relative devbox-workspace path.

---

## Appendix B: Automation Script

Save these as phase scripts in `/opt/devbox/scripts/` on the VPS:

### `phase1-backup.sh` (run on current host)

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="${1:-/tmp/devbox-migration}"
mkdir -p "$BACKUP_DIR"

VOLUMES=(
  devbox-abhishek_devbox-home devbox-himanshu_devbox-home
  devbox-rupam_devbox-home devbox-keshav_devbox-home
  devbox-abhishek_tsstate devbox-himanshu_tsstate
  devbox-rupam_tsstate devbox-keshav_tsstate
  shared-infra_shared-pgdata shared-infra_shared-keycloak-pgdata
  shared-infra_shared-redisdata
)

echo "=== Backing up Docker volumes ==="
for vol in "${VOLUMES[@]}"; do
  echo "  → $vol"
  docker run --rm -v "$vol":/source -v "$BACKUP_DIR":/backup alpine \
    tar czf "/backup/${vol}.tar.gz" -C /source .
done

echo "=== Saving Docker images ==="
docker save devbox-abhishek-devbox devbox-himanshu-devbox \
  devbox-rupam-devbox devbox-keshav-devbox | gzip > "$BACKUP_DIR/devbox-images.tar.gz"

echo "=== Copying config files ==="
tar czf "$BACKUP_DIR/config.tar.gz" -C /home/abhishekbhar/nixconf devcontainer/

echo ""
echo "Backup complete: $BACKUP_DIR"
echo "Total size: $(du -sh "$BACKUP_DIR" | cut -f1)"
```

### `phase2-restore.sh` (run on VPS)

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="${1:-/opt/devbox-migration}"

echo "=== Restoring Docker volumes ==="
for f in "$BACKUP_DIR"/*_devbox-home.tar.gz \
         "$BACKUP_DIR"/*_tsstate.tar.gz \
         "$BACKUP_DIR"/shared-infra_*.tar.gz; do
  [ -f "$f" ] || continue
  vol_name=$(basename "$f" .tar.gz)
  echo "  → $vol_name"
  docker volume create "$vol_name" 2>/dev/null || true
  docker run --rm -v "$vol_name":/dest -v "$BACKUP_DIR":/backup alpine \
    tar xzf "/backup/$(basename "$f")" -C /dest
done

echo "=== Loading Docker images ==="
gunzip -c "$BACKUP_DIR/devbox-images.tar.gz" | docker load

echo "=== Restoring config ==="
mkdir -p /opt/devbox
tar xzf "$BACKUP_DIR/config.tar.gz" -C /opt/devbox/

echo ""
echo "Restore complete. Proceed to Phase 3 (deploy shared infra) and Phase 4 (deploy devboxes)."
```

---

## Appendix C: Verification Checklist

| # | Check | How |
|---|---|---|
| 1 | All 12 containers running | `docker ps --format '{{.Names}} {{.Status}}'` |
| 2 | Tailscale IPs unchanged | `docker exec ts-abhishek tailscale ip -4` → `100.94.43.18` |
| 3 | SSH to each devbox | `ssh coder@devbox-abhishek` (MagicDNS) |
| 4 | code-server accessible | `curl -sI http://100.94.43.18:13337` → `200` |
| 5 | Postgres data intact | `docker exec shared-postgres psql -U algomatter -c '\l'` |
| 6 | Keycloak admin UI | `curl -sI http://127.0.0.1:8180` → `200` |
| 7 | Redis responsive | `docker exec shared-redis redis-cli ping` → `PONG` |
| 8 | Docker socket works inside devbox | `docker exec devbox-abhishek docker ps` |
| 9 | DNS resolution inside devbox | `docker exec devbox-abhishek ping shared-postgres` |
| 10 | Git SSH keys in place | `docker exec devbox-abhishek ls -la ~/.ssh/id_ed25519` |

# Dev Container — Multi-developer Dev Environment

Replaces Coder workspaces with a **Tailscale sidecar** pattern.
Each developer on the team gets their own container pair (sidecar +
dev container) sharing a network namespace on the Docker host (vajra).

## Architecture

```
                         ┌── vajra (NixOS) ──────────────────────┐
                         │                                        │
Your laptop ──tailscale──┼── devbox-abhishek project              │
                         │   ┌────────────────┐  ┌─────────────┐ │
                         │   │ ts-abhishek    │  │ devbox-     │ │
                         │   │ (sidecar)      │  │ abhishek    │ │
                         │   │                │  │             │ │
                         │   │ tailscale      │──│ sshd :22    │ │
                         │   │ NET_ADMIN      │  │ code-srv    │ │
                         │   │ /dev/net/tun   │  │ :13337      │ │
                         │   │                │  │ Nix + tools │ │
                         │   │ tsstate volume │  │ home volume │ │
                         │   └────────────────┘  └─────────────┘ │
                         │         │ shared network namespace     │
                         │         └──────────────────────────────│
                         │                                        │
                         │   devbox-jane project                  │
                         │   ┌────────────────┐  ┌─────────────┐ │
                         │   │ ts-jane        │  │ devbox-jane │ │
                         │   │ same pattern)  │  │             │ │
                         │   └────────────────┘  └─────────────┘ │
                         │                                        │
                         │   /var/run/docker.sock (shared)        │
                         └────────────────────────────────────────┘
```

**Why a sidecar?**
- Tailscale runs in the **official** `tailscale/tailscale` image — no sudo tricks
- Upgrade Tailscale independently: `docker compose pull tailscale && compose up -d tailscale`
- The dev container has no tailscale dependency — simpler, cleaner
- NET_ADMIN capability is on the sidecar only, not the dev container
- The sidecar handles auth, state, and networking; the dev container just runs dev tools

---

## Multi-developer workflow

This section covers the complete workflow for a team using this setup.
For a quick single-user start, skip to [Quick start](#quick-start).

### The model: one container pair per developer

Each developer runs their **own Compose project**. Project name
(`-p devbox-<name>`) isolates everything:

| Layer | Isolated by | Example for `jane` |
|-------|-------------|---------------------|
| Sidecar container | `container_name` + `-p` prefix | `devbox-jane-ts-1` |
| Dev container | `container_name` + `-p` prefix | `devbox-jane-devbox-1` |
| Tailscale hostname | `TS_HOSTNAME` env | `devbox-jane` |
| Home directory | Project-prefixed Docker volume | `devbox-jane_devbox-home` |
| Tailscale auth state | Project-prefixed Docker volume | `devbox-jane_tsstate` |
| Network | `network_mode: service:tailscale` | Shared within project pair |
| Auth key | Per-user `.env` file | `.env.jane` |

### What each developer needs

| Requirement | How they get it |
|-------------|-----------------|
| Tailscale installed | [tailscale.com/download](https://tailscale.com/download) |
| On the team tailnet | Admin invites them via Tailscale admin console |
| SSH key pair | They already have one (or generate: `ssh-keygen -t ed25519`) |
| The dev container's public key | Admin adds it to Git hosts for repo access |

That's it. **No Docker. No Nix. No code-server. No repo clone**
on their machine — they work entirely inside the container.

### Onboarding a new developer (admin view)

#### Step 1: Create their env file

```bash
cd /home/abhishekbhar/nixconf/devcontainer
make devbox-add DEV=jane
# → Creates .env.jane from .env.example
```

#### Step 2: Create a Tailscale auth key for them

Go to **[login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)**
→ **Generate auth key**:

- **Tags:** `tag:devbox` (or a tag you create for dev containers)
- **Ephemeral:** Off (so the container keeps its identity across restarts)
- **Description:** `devbox-jane`

Copy the generated key (starts with `tskey-auth-...`).

#### Step 3: Fill in their `.env.jane`

```bash
$EDITOR .env.jane
```

```env
DEV_USER="jane"

DEV_CPUS="4"
DEV_MEMORY="8G"

GIT_USER_NAME="Jane Doe"
GIT_USER_EMAIL="jane@company.com"

# The auth key you just created in Tailscale admin
TS_AUTH_KEY="tskey-auth-xxxxxxxxxxxxxxxxxxxx"

# Jane's SSH public key (she sends you this)
SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... jane@laptop"
```

#### Step 4: Build and start

```bash
make devbox-build DEV=jane
make devbox-up DEV=jane
```

This starts two containers:

```
devbox-jane-ts-1       (Tailscale sidecar — appears as "devbox-jane" on tailnet)
devbox-jane-devbox-1   (Dev container — shares sidecar's network, runs sshd + tools)
```

#### Step 5: Register the container's SSH key on your Git host

```bash
make devbox-shell DEV=jane cat /home/coder/.ssh/id_ed25519.pub
```

Add the output to **git.abhibhr.in** (Forgejo) or GitHub as a deploy key
or attached to Jane's user account.

#### Step 6: Tell Jane to connect

Send Jane her tailnet hostname. She connects from anywhere:

```bash
ssh coder@devbox-jane
```

If she doesn't have MagicDNS enabled, give her the IP instead:

```bash
tailscale ip -4 devbox-jane
# → 100.x.x.x
ssh coder@100.x.x.x
```

### Developer's daily workflow (Jane's view)

#### First-time SSH config

Jane adds this to her `~/.ssh/config` for convenience:

```
Host devbox-jane
  HostName devbox-jane
  User coder
  StrictHostKeyChecking accept-new
  IdentityFile ~/.ssh/id_ed25519
```

Then it's just:

```bash
ssh devbox-jane
```

#### Inside the container

Jane lands in `/home/coder/workspace/`. Everything is ready:

- **Nix + flakes:** `nix develop` works, `nix build` works
- **direnv:** auto-loads project `.envrc` on `cd`
- **code-server:** open `http://100.x.x.x:13337` in a browser
- **Docker:** can run containers (shares host Docker socket)
- **Pi agent:** `pi` command for AI-assisted coding
- **Git:** `git pull`, `git push` to Forgejo/GitHub (key is already registered)

#### Getting project code

```bash
# Jane clones her own copy into her isolated workspace
cd ~/workspace
git clone git@git.abhibhr.in:team/project.git
cd project
# direnv auto-loads the flake
```

#### Browser IDE

Jane opens `http://100.x.x.x:13337` in any browser — code-server
gives her a full VS Code experience. No install needed.

---

### Admin responsibilities

| Task | How |
|------|-----|
| **Add a developer** | `make devbox-add DEV=jane` → edit `.env.jane` → `make devbox-up DEV=jane` |
| **Remove a developer** | `make devbox-down DEV=jane` → `rm .env.jane` → optionally `docker compose -p devbox-jane down -v` to delete volumes |
| **Rotate SSH keys** | Update `SSH_PUBLIC_KEYS` in `.env.jane` → restart with `make devbox-up DEV=jane` |
| **Revoke Tailscale access** | Delete their auth key in Tailscale admin → container loses connectivity |
| **Adjust resources** | Change `DEV_CPUS`/`DEV_MEMORY` in `.env.jane` → restart |
| **Monitor resources** | `docker stats` / `htop` on vajra to see all containers |
| **Upgrade Tailscale** | `docker compose -p devbox-jane pull tailscale && make devbox-up DEV=jane` |

### Resource planning on vajra

| Developer | CPUs | RAM | Disk (home volume) |
|-----------|------|-----|-------------------|
| Abhishek  | 4    | 8 GB | ~1-2 GB |
| Jane      | 4    | 8 GB | ~1-2 GB |
| Bob       | 4    | 8 GB | ~1-2 GB |
| **Total** | **12** (over-committed) | **24 GB** | **~6 GB** |

vajra has 8 real cores / 32 GB RAM. Over-committing CPUs is fine
(they time-share). Memory is the hard limit — 3 devs at 8 GB each uses
24/32 GB, leaving headroom for the host OS and services.

### Sharing project files

**Option A: Each developer clones their own copy** (simpler)

```bash
# Inside each container:
cd ~/workspace
git clone git@git.abhibhr.in:team/project.git
```

- Pro: Full isolation, independent branches, no git permission conflicts
- Pro: No admin overhead for file permissions
- Con: Disk space (but Docker volumes are thin, and Nix store is shared via layer caching)

Files sync via git — standard workflow.

**Option B: Bind-mount a shared workspace** (for tighter collaboration)

Uncomment in `docker-compose.yml`:

```yaml
volumes:
  - /mnt/storage/projects/jane:/home/coder/workspace
```

Admin creates the directories:

```bash
sudo mkdir -p /mnt/storage/projects/{abhishek,jane,bob}
sudo chown -R 1000:1000 /mnt/storage/projects
```

Each developer gets their own directory, but you can also create
shared directories that multiple containers mount.

---

## Quick start (single user)

### 1. Create a Tailscale pre-auth key

```bash
tailscale authkey --ephemeral=false --tag devbox
```

### 2. Create your env file

```bash
cd /home/abhishekbhar/nixconf/devcontainer
cp .env.example .env.abhishek
$EDITOR .env.abhishek
```

Fill in:
- `DEV_USER="abhishek"`
- `GIT_USER_NAME`, `GIT_USER_EMAIL`
- `TS_AUTH_KEY` — paste the key from step 1
- `SSH_PUBLIC_KEYS` — your SSH public key (`cat ~/.ssh/id_ed25519.pub`)

### 3. Build & start

```bash
make devbox-build DEV=abhishek
make devbox-up DEV=abhishek
```

Or in one shot:

```bash
docker compose -f devcontainer/docker-compose.yml \
  --env-file .env.abhishek -p devbox-abhishek up -d --build
```

### 4. Connect

```bash
# Find the tailnet IP:
tailscale ip -4 devbox-abhishek

# SSH (regular SSH over tailnet — traffic encrypted by wireguard):
ssh coder@<that-ip>

# Or with MagicDNS:
ssh coder@devbox-abhishek

# Browser IDE:
open http://<that-ip>:13337
```

---

## Connecting

### SSH over tailnet (recommended)

```bash
# With MagicDNS:
ssh coder@devbox-abhishek

# Or by IP:
tailscale ip -4 devbox-abhishek
ssh coder@<that-ip>
```

Add this to `~/.ssh/config` for zero-friction:

```
Host devbox-*
  User coder
  StrictHostKeyChecking accept-new
  IdentityFile ~/.ssh/id_ed25519
```

Then it's just `ssh devbox-abhishek`.

### Browser IDE

`http://<tailscale-ip>:13337` — code-server runs with `--auth none`
(no password; it's on your private tailnet).

### From the host (vajra)

```bash
make devbox-shell DEV=abhishek
```

Or directly:

```bash
docker compose -f devcontainer/docker-compose.yml \
  --env-file .env.abhishek -p devbox-abhishek exec devbox bash
```

### VS Code Dev Containers

Open the `nixconf` repo in VS Code, then `Cmd+Shift+P` →
**Dev Containers: Reopen in Container**.

This picks up `.devcontainer/devcontainer.json` which references the
compose file. The dev container's `.env` (gitignored) should have your
identity and `TS_AUTH_KEY`.

---

## Makefile commands

```bash
make devbox-up DEV=abhishek      # Start Abhishek's containers
make devbox-up DEV=jane          # Start Jane's containers
make devbox-down DEV=jane        # Stop Jane's containers
make devbox-logs DEV=abhishek    # Follow Abhishek's logs
make devbox-shell DEV=abhishek   # Shell into dev container
make devbox-rebuild DEV=jane     # Rebuild image + restart
make devbox-add DEV=jane         # Create .env.jane from template

# Default DEV=abhishek:
make devbox-up                   # starts devbox-abhishek
```

---

## SSH key management

Two key pairs are involved:

| Direction | Key | Managed by |
|-----------|-----|-----------|
| **You → container** | Your public key in `SSH_PUBLIC_KEYS` in `.env` | Entrypoint adds it to `~/.ssh/authorized_keys` on every start |
| **Container → Git hosts** | Container's `id_ed25519.pub` auto-generated on first start | Print it and register on GitHub/Forgejo |

### First connection

```bash
# If SSH_PUBLIC_KEYS is set correctly, this just works:
ssh coder@devbox-abhishek

# If not, fix from the host:
make devbox-shell DEV=abhishek
echo "your-public-key" >> ~/.ssh/authorized_keys
```

### Register container's Git SSH key

```bash
make devbox-shell DEV=abhishek cat /home/coder/.ssh/id_ed25519.pub
# Add to GitHub / Forgejo as an SSH key
```

---

## What's in the box

| Feature | Container | Description |
|---------|-----------|-------------|
| **Tailscale** | Sidecar | Official image, kernel TUN, persistent state |
| **Nix** | Dev | Single-user Nix with flakes |
| **direnv** | Dev | Auto-load `.envrc` + `flake.nix` |
| **code-server** | Dev | Browser IDE on port 13337 |
| **Pi agent** | Dev | `pi` command for AI coding |
| **Docker** | Dev | `/var/run/docker.sock` mounted (DooD) |
| **SSH** | Dev | OpenSSH server, key-only auth |
| **Git** | Dev | Pre-configured per developer, SSH keys auto-generated |

---

## Persistence

Volumes survive container rebuilds:

| Volume | Contains |
|--------|----------|
| `devbox-<name>_devbox-home` | `/home/coder` (SSH keys, git config, Nix profile, bash history) |
| `devbox-<name>_tsstate` | Tailscale auth state (stays logged in) |

Rebuild without losing state:

```bash
make devbox-down DEV=abhishek
make devbox-rebuild DEV=abhishek
```

---

## Auto-start on boot (NixOS)

```nix
# hosts/vajra/system.nix
{
  imports = [
    # ./coder.nix          # comment out to disable Coder
    ../../modules/nixos/devbox.nix
  ];

  services.devbox = {
    enable = true;
    users  = [ "abhishek" "jane" ];
  };
}
```

Creates `devbox-abhishek.service` and `devbox-jane.service` — each
runs `docker compose -p devbox-<name> up` on boot.

```bash
sudo nixos-rebuild switch --flake .#vajra
systemctl status devbox-abhishek
```

---

## Resource limits

Per-developer in their `.env`:

```bash
DEV_CPUS="4"
DEV_MEMORY="8G"
```

Remove limits for host-native performance:

```bash
DEV_CPUS="0"
DEV_MEMORY="0"
```

---

## Upgrading Tailscale

```bash
# Per developer — pull latest and restart just the sidecar
docker compose -f devcontainer/docker-compose.yml \
  --env-file .env.abhishek -p devbox-abhishek pull tailscale

docker compose -f devcontainer/docker-compose.yml \
  --env-file .env.abhishek -p devbox-abhishek up -d tailscale
```

No dev container rebuild needed. For a team, script this:

```bash
for dev in abhishek jane bob; do
  docker compose -f devcontainer/docker-compose.yml \
    --env-file .env.$dev -p devbox-$dev pull tailscale
  docker compose -f devcontainer/docker-compose.yml \
    --env-file .env.$dev -p devbox-$dev up -d tailscale
done
```

---

## Comparison: Coder vs Dev Container (sidecar)

| Aspect | Coder | Dev Container |
|--------|-------|---------------|
| **Architecture** | Coder server + Postgres + per-workspace containers | Tailscale sidecar + dev container |
| **Multi-developer** | Coder workspaces via dashboard | One compose project per dev |
| **Access** | Browser → Cloudflare → NPM → Coder | Direct SSH over tailnet |
| **Auth** | Coder accounts + passwords | Tailnet auth + SSH keys |
| **Tailscale** | Not used | Official sidecar, independently upgradeable |
| **Security** | egress firewall on Docker bridge | Same + tailnet-only access |
| **Starting a workspace** | Coder UI → button click | Container always-on (systemd) |
| **Developer machine req** | Any browser | Tailscale + SSH client |
| **Complexity** | Server + DB + proxy + Terraform | Two containers, one compose file |

---

## Troubleshooting

**Tailscale sidecar not healthy:**
```bash
docker compose -f devcontainer/docker-compose.yml \
  --env-file .env.abhishek -p devbox-abhishek logs tailscale
# Check: is the auth key valid? Has it been revoked?
```

**Dev container didn't start (waiting on tailscale):**
`devbox` waits for the tailscale healthcheck. Check tailscale first:
```bash
docker compose -f devcontainer/docker-compose.yml \
  --env-file .env.abhishek -p devbox-abhishek ps
```

**Can't SSH in:**
```bash
# Check SSH_PUBLIC_KEYS is set in .env
# Or exec in from the host:
make devbox-shell DEV=abhishek
cat ~/.ssh/authorized_keys
# Add key manually if needed
```

**Can't find the tailnet IP:**
```bash
tailscale ip -4 devbox-abhishek
# If nothing shows, the sidecar hasn't authenticated yet.
# Check the auth key.
```

**Can't reach code-server:**
```bash
# Verify from vajra:
make devbox-shell DEV=abhishek
curl -s http://localhost:13337/healthz
# If not running, check /tmp/code-server.log inside the container
```

**Port conflict?** No host port mapping — all traffic goes through
the tailnet. Each container pair gets its own Tailscale IP, so no
port conflicts between developers.

**How to stop/remove a developer entirely:**
```bash
make devbox-down DEV=jane
# Optionally remove volumes (destroys home + tailscale state):
docker compose -p devbox-jane down -v
rm devcontainer/.env.jane
```

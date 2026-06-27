terraform {
  required_providers {
    coder  = { source = "coder/coder" }
    docker = { source = "kreuzwerker/docker" }
  }
}

provider "docker" {}

data "coder_workspace"       "me" {}
data "coder_workspace_owner" "me" {}

# ---------- workspace parameters ----------

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU cores"
  description  = "vCPU limit for the workspace container."
  type         = "number"
  default      = "4"
  mutable      = true
  validation {
    min = 2
    max = 8
  }
}

data "coder_parameter" "memory_gb" {
  name         = "memory_gb"
  display_name = "Memory (GiB)"
  description  = "RAM limit for the workspace container."
  type         = "number"
  default      = "8"
  mutable      = true
  validation {
    min = 4
    max = 16
  }
}

data "coder_parameter" "git_email" {
  name         = "git_email"
  display_name = "Git email for SSH key"
  description  = "Email to embed in the generated SSH key. Leave blank to use your Coder account email."
  type         = "string"
  default      = data.coder_workspace_owner.me.email
  mutable      = false
}

# ---------- agent ----------

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  # Pre-set git identity to the Coder user so devs can't push as someone else
  # without first overriding both name AND email — combined with the egress
  # firewall (Phase 5), this funnels pushes to the internal Git host.
  env = {
    GIT_AUTHOR_NAME     = data.coder_workspace_owner.me.full_name
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = data.coder_workspace_owner.me.full_name
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  startup_script_behavior = "blocking"
  startup_script          = <<-EOT
    set -e
    mkdir -p /home/coder/workspace /home/coder/.ssh

    # ── Git user config ────────────────────────────────────────
    git config --global user.name  "${data.coder_workspace_owner.me.full_name}" 2>/dev/null || true
    git config --global user.email "${data.coder_workspace_owner.me.email}" 2>/dev/null || true
    git config --global ssh.variant ssh 2>/dev/null || true

    # ── Pi coding agent PATH (for "pi" command) ────────────────
    if [ -d "\$HOME/.local/node/bin" ]; then
      export PATH="\$HOME/.local/node/bin:\$PATH"
      export LD_LIBRARY_PATH="\$HOME/.local/node/lib"
    fi

    # ── SSH key (generate once, persists across restarts) ──────
    SSH_EMAIL="${data.coder_parameter.git_email.value}"
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
      ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
      echo "  ✓ SSH key generated for $SSH_EMAIL"
    fi

    # ── SSH config (stricthostkeychecking for git on first connect) ─
    if [ ! -f "$HOME/.ssh/config" ]; then
      cat > "$HOME/.ssh/config" << 'SSHEOF'
Host git.abhibhr.in
  HostName git.abhibhr.in
  Port 2222
  User git
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
SSHEOF
      chmod 600 "$HOME/.ssh/config"
    fi

    # ── code-server ────────────────────────────────────────────
    /usr/bin/code-server \
      --auth none \
      --bind-addr 0.0.0.0:13337 \
      /home/coder/workspace >/tmp/code-server.log 2>&1 &
  EOT

  metadata {
    display_name = "CPU usage"
    key          = "cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "RAM usage"
    key          = "mem_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

# ---------- apps surfaced in the dashboard ----------

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/coder/workspace"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "authenticated"
  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

# Generic frontend preview slot. Devs run their app on :3000 inside the
# workspace; this opens https://3000--... via the wildcard proxy.
resource "coder_app" "frontend" {
  agent_id     = coder_agent.main.id
  slug         = "frontend"
  display_name = "Frontend (3000)"
  url          = "http://localhost:3000"
  subdomain    = false
  share        = "authenticated"
}

# ---------- dedicated docker network ----------
# Pinned bridge name so the host-side egress firewall (Phase 5) can target
# workspace traffic specifically via `-i br-coderws`. Linux caps interface
# names at 15 chars; br-coderws is 10.
data "docker_network" "workspaces" {
  name = "coder-workspaces"
}

# ---------- per-workspace state ----------

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle { ignore_changes = all }
}

resource "docker_image" "main" {
  name = "coder-nix:latest"
  build {
    context = "${path.module}/build"
  }
  keep_locally = true
}

# ---------- workspace container ----------

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.main.image_id
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  entrypoint = ["sh", "-c", coder_agent.main.init_script]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  user = "1000:1000"

  # Resource caps from parameters
  cpu_shares = data.coder_parameter.cpu.value * 1024
  memory     = data.coder_parameter.memory_gb.value * 1024

  # Hardening
  privileged = false
  capabilities {
    drop = ["ALL"]
  }
  security_opts = [
    "no-new-privileges:true",
  ]

  group_add = [131]

  networks_advanced {
    name = data.docker_network.workspaces.name
  }

  # Pin DNS directly to PiHole on server2 — split-horizon for *.abhibhr.in
  # without depending on vajra's resolver / Tailscale MagicDNS.
  dns = ["192.168.11.102"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = false
  }
}

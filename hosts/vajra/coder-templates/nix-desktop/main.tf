# ─────────────────────────────────────────────────────────────────────
# nix-desktop — Coder template: native desktop development via KasmVNC
# ─────────────────────────────────────────────────────────────────────
# Developers work inside the native XFCE4 desktop (accessed via
# browser). No browser-based VS Code — use Zed, Chrome, and terminal
# from the desktop. CLI access via `coder ssh` remains available.
#
# Features:
#   * XFCE4 desktop via KasmVNC (official Coder module)
#   * Google Chrome + Zed editor inside the desktop
#   * Nix (flakes) + direnv for project environments
#   * Git identity locked to the Coder user (no push impersonation)
#   * CLI access via `coder ssh <workspace>`
# ─────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    coder  = { source = "coder/coder" }
    docker = { source = "kreuzwerker/docker" }
  }
}

provider "docker" {}

data "coder_workspace"       "me" {}
data "coder_workspace_owner" "me" {}

# ═══════════════════════════════════════════════════════════════════
# WORKSPACE PARAMETERS
# ═══════════════════════════════════════════════════════════════════

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

data "coder_parameter" "desktop_resolution" {
  name         = "desktop_resolution"
  display_name = "Desktop resolution"
  description  = "Resolution for the VNC virtual display."
  type         = "string"
  default      = "1920x1080"
  mutable      = true
  option {
    name  = "1920×1080 (FHD)"
    value = "1920x1080"
  }
  option {
    name  = "2560×1440 (QHD)"
    value = "2560x1440"
  }
  option {
    name  = "3840×2160 (4K)"
    value = "3840x2160"
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

# ═══════════════════════════════════════════════════════════════════
# AGENT
# ═══════════════════════════════════════════════════════════════════

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  # ── Git identity: locked to the Coder user ─────────────────────
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

    # KasmVNC is started by the KasmVNC module's coder_script
    # (run_on_start = true). No manual startup needed here.
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

# ═══════════════════════════════════════════════════════════════════
# KASMVNC MODULE — official Coder desktop module
# ═══════════════════════════════════════════════════════════════════

module "kasmvnc" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/kasmvnc/coder"
  version             = "1.3.0"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
  subdomain           = false
}

# ═══════════════════════════════════════════════════════════════════
# CODER APPS
# ═══════════════════════════════════════════════════════════════════
# The KasmVNC module creates the "kasm-vnc" app automatically.
# No code-server / VS Code — developers use native Zed in the desktop.
# The frontend preview app is available if the developer runs
# something on port 3000 inside the desktop.

resource "coder_app" "frontend" {
  agent_id     = coder_agent.main.id
  slug         = "frontend"
  display_name = "Frontend (3000)"
  url          = "http://localhost:3000"
  subdomain    = false
  share        = "authenticated"
}

# ═══════════════════════════════════════════════════════════════════
# DOCKER NETWORK (shared with the `nix` template)
# ═══════════════════════════════════════════════════════════════════

data "docker_network" "workspaces" {
  name = "coder-workspaces"
}

# ═══════════════════════════════════════════════════════════════════
# PERSISTENT HOME VOLUME
# ═══════════════════════════════════════════════════════════════════

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle { ignore_changes = all }
}

# ═══════════════════════════════════════════════════════════════════
# WORKSPACE IMAGE
# ═══════════════════════════════════════════════════════════════════

resource "docker_image" "main" {
  name = "coder-nix-desktop:latest"
  build {
    context = "${path.module}/build"
  }
  keep_locally = true
}

# ═══════════════════════════════════════════════════════════════════
# WORKSPACE CONTAINER
# ═══════════════════════════════════════════════════════════════════

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.main.image_id
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  entrypoint = ["sh", "-c", coder_agent.main.init_script]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  user = "1000:1000"

  cpu_shares = data.coder_parameter.cpu.value * 1024
  memory     = data.coder_parameter.memory_gb.value * 1024

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

#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Dev container entrypoint
# ─────────────────────────────────────────────────────────────────────
# Starts as root for system setup, then hands off to the target user.
#
# Starts:
#   1. sshd (password auth — on port 22, via tailnet)
#   2. code-server (browser IDE on port 13337)
#
# Environment variables:
#   DEV_USER       — Developer short name (default: coder)
#   DEV_PASSWORD   — SSH password for the developer (default: none)
#   GIT_USER_NAME  — Git author name
#   GIT_USER_EMAIL — Git author email
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
IFS=$'\n\t'

DEV_USER="${DEV_USER:-coder}"
DEV_PASSWORD="${DEV_PASSWORD:-}"
GIT_USER_NAME="${GIT_USER_NAME:-Developer}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-dev@example.com}"

# ── Phase 1: run as root for system-level setup ──────────────────
if [ "$(id -u)" = "0" ]; then

  echo ""
  echo "  ── Dev container for ${DEV_USER} ──────────────────────────────"
  echo ""

  # Rename user if different from image default
  if [ "$DEV_USER" != "coder" ]; then
    if id "coder" &>/dev/null && ! id "$DEV_USER" &>/dev/null; then
      echo "  → Renaming coder → ${DEV_USER}..."
      usermod -l "$DEV_USER" coder
      groupmod -n "$DEV_USER" coder 2>/dev/null || true
      usermod -d /home/coder "$DEV_USER"
      mv /etc/sudoers.d/coder "/etc/sudoers.d/$DEV_USER" 2>/dev/null || true
      sed -i "s/coder/$DEV_USER/g" "/etc/sudoers.d/$DEV_USER" 2>/dev/null || true
      chown -R "$DEV_USER":"$DEV_USER" /home/coder 2>/dev/null || true
      echo "  ✓ User renamed to ${DEV_USER}"
    fi
  fi

  # Set password if provided
  if [ -n "$DEV_PASSWORD" ]; then
    echo "$DEV_USER:$DEV_PASSWORD" | chpasswd
    echo "  ✓ Password set for ${DEV_USER}"
  else
    echo "  ⚠ No DEV_PASSWORD set — SSH password auth disabled"
  fi

  # Start sshd

  # Add user to docker-access group (GID from Docker socket)
  DOCKER_GID=$(stat -c %g /var/run/docker.sock 2>/dev/null || echo "")
  if [ -n "$DOCKER_GID" ]; then
    # Check if this GID exists (as any group name)
    if ! id "$DEV_USER" 2>/dev/null | grep -qw "$DOCKER_GID"; then
      # Create group with this GID if it does not exist
      getent group "$DOCKER_GID" >/dev/null 2>&1 ||
        groupadd -g "$DOCKER_GID" "host-docker-${DOCKER_GID}" 2>/dev/null || true
      usermod -aG "$DOCKER_GID" "$DEV_USER" 2>/dev/null || true
      echo "  ✓ Added ${DEV_USER} to docker-access group (GID ${DOCKER_GID})"
    fi
  fi
  echo "  → Starting sshd..."
  mkdir -p /run/sshd
  tee /etc/ssh/sshd_config.d/99-devbox.conf >/dev/null <<SSHDEOF
Port 22
ListenAddress 0.0.0.0
PasswordAuthentication yes
PermitEmptyPasswords no
PubkeyAuthentication no
UsePAM no
AllowUsers ${DEV_USER}
PrintMotd no
SSHDEOF

  /usr/sbin/sshd -D >/tmp/sshd.log 2>&1 &
  echo "  ✓ sshd ready (user: ${DEV_USER}, password auth)"

  # Re-exec as the target user
  export HOME="/home/coder"
  exec su - "${DEV_USER}" -c "
    export DEV_USER='${DEV_USER}'
    export GIT_USER_NAME='${GIT_USER_NAME}'
    export GIT_USER_EMAIL='${GIT_USER_EMAIL}'
    export HOME=/home/coder
    /opt/devbox/entrypoint.sh --user-setup
  "
fi

# ── Phase 2: run as DEV_USER for user-level setup ────────────────
if [ "${1:-}" = "--user-setup" ]; then

  echo ""
  echo "  ── User setup for ${DEV_USER} ─────────────────────────────────"
  echo ""

  # Git config
  git config --global user.name  "${GIT_USER_NAME}"  2>/dev/null || true
  git config --global user.email "${GIT_USER_EMAIL}" 2>/dev/null || true
  git config --global ssh.variant ssh 2>/dev/null || true
  echo "  ✓ Git: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"

  # SSH key (outbound — for GitHub, Forgejo push/pull access)
  if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "${GIT_USER_EMAIL} [${DEV_USER}]" \
      -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
    echo "  ✓ Git SSH key generated"
    echo "  ─────────────────────────────────────────────────────"
    echo "  Add this to your Git host (GitHub / Forgejo):"
    echo ""
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
    echo "  ─────────────────────────────────────────────────────"
  fi

  # Git SSH config
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
    echo "  ✓ SSH config created (git.abhibhr.in + github.com)"
  fi

  # code-server
  if command -v /usr/bin/code-server &>/dev/null; then
    /usr/bin/code-server \
      --auth none \
      --bind-addr "0.0.0.0:13337" \
      "${HOME}/workspace" \
      >/tmp/code-server.log 2>&1 &
    echo "  ✓ code-server on http://0.0.0.0:13337"
  fi

  # Status
  echo ""
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║  Dev container ready  (${DEV_USER})                        ║"
  echo "  ║                                                        ║"
  echo "  ║  tailscale ip -4 devbox-${DEV_USER}                       ║"
  echo "  ║                                                        ║"
  echo "  ║  SSH:     ssh ${DEV_USER}@<that-ip>                       ║"
  echo "  ║           password: ${DEV_PASSWORD:-not set}                ║"
  echo "  ║                                                        ║"
  echo "  ║  Browser: http://<that-ip>:13337                         ║"
  echo "  ║                                                        ║"
  echo "  ║  Or with MagicDNS:                                     ║"
  echo "  ║    ssh ${DEV_USER}@devbox-${DEV_USER}                     ║"
  echo "  ║                                                        ║"
  echo "  ║  Logs: /tmp/{sshd,code-server}.log                     ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo ""
fi

# Keep alive
exec tail -f /dev/null

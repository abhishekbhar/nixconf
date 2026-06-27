#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Dev container entrypoint (no Tailscale — handled by sidecar)
# ─────────────────────────────────────────────────────────────────────
# Runs inside the tailscale sidecar's network namespace. Starts:
#   1. sshd (on port 22 — accessible via tailnet IP)
#   2. code-server (browser IDE on port 13337)
#
# SSH key management: add your public key(s) to the SSH_PUBLIC_KEYS
# env var in your .env file (newline-separated). The entrypoint adds
# them to authorized_keys on every start.
#
# Environment variables:
#   DEV_USER         — Developer short name
#   GIT_USER_NAME    — Git author name
#   GIT_USER_EMAIL   — Git author email
#   SSH_PUBLIC_KEYS  — Newline-separated SSH public keys for auth
# ─────────────────────────────────────────────────────────────────────

# ── Developer identity ─────────────────────────────────────────────
DEV_USER="${DEV_USER:-coder}"
GIT_USER_NAME="${GIT_USER_NAME:-Developer}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-dev@example.com}"

echo ""
echo "  ── Dev container for ${DEV_USER} ──────────────────────────────"
echo ""

# ── Git config ────────────────────────────────────────────────────
git config --global user.name  "${GIT_USER_NAME}"  2>/dev/null || true
git config --global user.email "${GIT_USER_EMAIL}" 2>/dev/null || true
git config --global ssh.variant ssh 2>/dev/null || true
echo "  ✓ Git: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"

# ── SSH key generation (for outbound SSH — GitHub, Forgejo, etc.) ─
SSH_EMAIL="${GIT_USER_EMAIL}"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "${SSH_EMAIL} [${DEV_USER}]" \
    -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
  echo "  ✓ Outbound SSH key generated for ${DEV_USER}"
  echo "  ─────────────────────────────────────────────────────"
  echo "  Public key (add to your Git host):"
  echo ""
  cat "$HOME/.ssh/id_ed25519.pub"
  echo ""
  echo "  ─────────────────────────────────────────────────────"
fi

# ── Git SSH config ────────────────────────────────────────────────
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

# ── SSH authorized_keys (inbound — your public key for SSH access) ─
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys"

# Add keys from SSH_PUBLIC_KEYS env var (one per line)
if [ -n "$SSH_PUBLIC_KEYS" ]; then
  # Clear and re-add on each start (in case keys are rotated)
  : > "$HOME/.ssh/authorized_keys"
  while IFS= read -r key; do
    if [ -n "$key" ]; then
      echo "$key" >> "$HOME/.ssh/authorized_keys"
    fi
  done <<< "$SSH_PUBLIC_KEYS"
  echo "  ✓ Added $(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ') SSH public key(s) from env"
else
  echo "  ⚠ SSH_PUBLIC_KEYS not set — no SSH access configured."
  echo "    Set it in your .env file with your public key:"
  echo "    SSH_PUBLIC_KEYS=\"ssh-ed25519 AAAAC3... your@email\""
fi

# ── start sshd ────────────────────────────────────────────────────
sudo mkdir -p /run/sshd
sudo tee /etc/ssh/sshd_config.d/99-devbox.conf >/dev/null <<SSHDEOF
Port 22
ListenAddress 0.0.0.0
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
UsePAM no
AllowUsers coder
PrintMotd no
Subsystem sftp /usr/lib/openssh/sftp-server
SSHDEOF

sudo /usr/sbin/sshd -D >/tmp/sshd.log 2>&1 &
echo "  ✓ sshd ready on port 22"

# ── start code-server ─────────────────────────────────────────────
if command -v /usr/bin/code-server &>/dev/null; then
  /usr/bin/code-server \
    --auth none \
    --bind-addr "0.0.0.0:13337" \
    /home/coder/workspace \
    >/tmp/code-server.log 2>&1 &
  echo "  ✓ code-server on http://0.0.0.0:13337"
fi

# ── Status ────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  Dev container ready  (${DEV_USER})                        ║"
echo "  ║                                                        ║"
echo "  ║  The tailscale sidecar is joining the tailnet now.      ║"
echo "  ║  Find the tailnet IP and connect:                       ║"
echo "  ║                                                        ║"
echo "  ║    tailscale ip -4 devbox-${DEV_USER}                     ║"
echo "  ║    ssh coder@<that-ip>                                 ║"
echo "  ║    http://<that-ip>:13337                               ║"
echo "  ║                                                        ║"
echo "  ║  Or use MagicDNS if enabled:                            ║"
echo "  ║    ssh coder@devbox-${DEV_USER}                          ║"
echo "  ║                                                        ║"
echo "  ║  Logs: /tmp/{sshd,code-server}.log                     ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Keep alive ────────────────────────────────────────────────────
exec tail -f /dev/null

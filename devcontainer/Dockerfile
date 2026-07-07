# ─────────────────────────────────────────────────────────────────────
# Dev container image (no Tailscale — handled by sidecar)
# ─────────────────────────────────────────────────────────────────────
# Runs in the tailscale sidecar's network namespace. Developers
# connect via VS Code Remote SSH or the code-server browser IDE.
# SSH uses password auth (DEV_PASSWORD env var).
#
# Features:
#   * Debian bookworm-slim base
#   * code-server (browser IDE on port 13337)
#   * Single-user Nix with flakes + direnv + nix-direnv
#   * Pi coding agent
#   * OpenSSH server (password auth via DEV_PASSWORD in .env)
#   * Docker-outside-of-Docker (mount /var/run/docker.sock)
#   * Git identity per developer
#   * SSH key auto-generated for Git host access
#   * User auto-renamed from coder → \$DEV_USER at startup
#   * Entrypoint at /opt/devbox/entrypoint.sh (outside volume mounts)
# ─────────────────────────────────────────────────────────────────────

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    USER=coder \
    HOME=/home/coder

# ── 1. System base ─────────────────────────────────────────────────
# Node.js 20 from NodeSource (apt only has Node 18, pi agent needs 20+)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils sudo bash openssh-server \
      docker.io \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Non-root user (UID 1000) with passwordless sudo ────────────
RUN useradd --create-home --uid 1000 --shell /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder

# ── 3. Nix (single-user, flakes enabled) ──────────────────────────
RUN mkdir -p /etc/nix \
 && printf 'experimental-features = nix-command flakes\n' > /etc/nix/nix.conf \
 && mkdir -m 0755 /nix && chown coder:coder /nix

# ── 4. Docker Compose plugin ──────────────────────────────────────
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
 && curl -fsSL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose \
 && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
 && ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# ── 5. code-server (browser IDE) ──────────────────────────────────
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ── 6. Pi coding agent ────────────────────────────────────────────
RUN npm install -g @earendil-works/pi-coding-agent

# ── 7. Pre-create working directories ─────────────────────────────
RUN mkdir -p /home/coder/.cache /home/coder/.local/share \
            /home/coder/workspace \
    && chown -R coder:coder /home/coder

# ── 8. Pre-configure sshd ────────────────────────────────────────
# The entrypoint (runs as root) overrides these with password auth.
# We just ensure the directory exists and the defaults are safe.
RUN mkdir -p /run/sshd \
    && sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# ── Everything below runs as non-root ─────────────────────────────
USER coder
WORKDIR /home/coder

# ── 9. Single-user Nix install (no daemon) ────────────────────────
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add

# ── 10. direnv + nix-direnv ─────────────────────────────────────
RUN . /home/coder/.nix-profile/etc/profile.d/nix.sh \
 && nix profile install nixpkgs#direnv nixpkgs#nix-direnv

RUN mkdir -p /home/coder/.config/direnv \
 && printf 'source %s/.nix-profile/share/nix-direnv/direnvrc\n' "$HOME" \
      > /home/coder/.config/direnv/direnvrc \
 && printf '\n# --- Nix + direnv (added by image) ---\n' \
      >> /home/coder/.bashrc \
 && printf 'if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then\n' \
      >> /home/coder/.bashrc \
 && printf '  . "$HOME/.nix-profile/etc/profile.d/nix.sh"\n' \
      >> /home/coder/.bashrc \
 && printf 'fi\n' >> /home/coder/.bashrc \
 && printf 'export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"\n' \
      >> /home/coder/.bashrc \
 && printf 'eval "$(direnv hook bash)"\n' >> /home/coder/.bashrc

# ── 11. Entrypoint — outside volume mounts ────────────────────────
# Stored in /opt/devbox (NOT /home/coder) so Docker volumes mounted
# at /home don't shadow the entrypoint after image rebuilds.
# The compose file overrides the user to "root" so the first phase
# of the entrypoint can manage users and start sshd.
COPY --chown=coder:coder scripts/entrypoint.sh /opt/devbox/entrypoint.sh
RUN chmod +x /opt/devbox/entrypoint.sh

ENTRYPOINT ["/opt/devbox/entrypoint.sh"]

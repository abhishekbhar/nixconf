# ─────────────────────────────────────────────────────────────────────
# nix-desktop — Coder workspace image: native desktop development
# ─────────────────────────────────────────────────────────────────────
# Provides:
#   * XFCE4 desktop via KasmVNC  (the primary development surface)
#   * Google Chrome              (for web dev / testing)
#   * Zed editor                 (native, runs inside the XFCE desktop)
#   * Nix (single-user, flakes)  + direnv + nix-direnv
#   * Git + identity enforcement via Coder env vars
#   * CLI access via `coder ssh` (terminal from outside)
#
# NO code-server / VS Code in browser. Developers work inside the
# native desktop environment using Zed, Chrome, and the terminal.
#
# Toolchains (JDK, Node, Go, Rust, Python, etc.) come from each
# project's flake.nix — NOT baked into this image.
# ─────────────────────────────────────────────────────────────────────

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    USER=coder \
    HOME=/home/coder

# ── 1. System + desktop + Chrome dependencies ──────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils sudo bash openssh-client docker.io \
      nodejs npm \
      # Desktop environment (lightweight) — required by KasmVNC module
      xfce4 xfce4-terminal dbus xinit dbus-x11 \
      # Software GPU so native editors (Zed, etc.) can render
      mesa-utils libgl1-mesa-dri libgl1 \
      # Google Chrome dependencies (not in slim)
      fonts-liberation libasound2 libnspr4 libnss3 libvulkan1 \
      wget xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Docker Compose plugin ─────────────────────────────────────
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
 && curl -fsSL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose \
 && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
 && ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# ── 3. Non-root user (UID 1000 matches main.tf) ───────────────────
RUN useradd --create-home --uid 1000 --shell /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# ── 3. KasmVNC (pre-installed — no-new-privileges blocks sudo) ────
RUN apt-get update \
    && apt-get install -y --no-install-recommends libdatetime-perl \
    && curl -fsSL https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_bookworm_1.4.0_amd64.deb \
         -o /tmp/kasmvnc.deb \
    && apt-get install -y /tmp/kasmvnc.deb \
    && rm /tmp/kasmvnc.deb \
    && rm -rf /var/lib/apt/lists/* \
    && chown -R coder:coder /usr/share/kasmvnc/www

# ── 4. Google Chrome (stable) ─────────────────────────────────────
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
      -o /tmp/chrome.deb \
    && apt-get update -qq \
    && apt-get install -y /tmp/chrome.deb \
    && rm /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Pi coding agent (LLM-driven development assistant) ───────
RUN npm install -g @earendil-works/pi-coding-agent

# ── 6. Nix (single-user, flakes enabled) ──────────────────────────
RUN mkdir -p /etc/nix \
 && printf 'experimental-features = nix-command flakes\n' > /etc/nix/nix.conf \
 && mkdir -m 0755 /nix && chown coder:coder /nix

# ── 6. Zed editor (native, runs in XFCE desktop) ──────────────────
RUN curl -fsSL https://zed.dev/install.sh | SHELL=/bin/bash sh

# ── 7. Pre-create coder's xdg directories owned by coder ──────────
RUN mkdir -p /home/coder/.cache /home/coder/.local/share \
    && chown -R coder:coder /home/coder/.cache /home/coder/.local

# ── Everything below runs as non-root coder ───────────────────────
USER coder
WORKDIR /home/coder

# ── 8. Single-user Nix install (no daemon) ────────────────────────
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add

# ── 9. direnv + nix-direnv (auto-load project flakes on cd) ───────
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

RUN mkdir -p /home/coder/workspace

# Minimal dev workspace image for Coder on vajra.
# - Debian slim base, no language toolchains baked in.
# - Single-user Nix (no daemon) with flakes enabled.
# - direnv + nix-direnv so a project's flake.nix + .envrc auto-loads on `cd`.
# - code-server (browser IDE) + the mkhl.direnv VS Code extension.
# - Non-root user `coder` UID 1000 (matches main.tf `user = "1000:1000"`).
#
# Toolchains (JDK, Node, etc.) come from each project's flake — not this image.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    USER=coder \
    HOME=/home/coder

# Minimal host tooling. xz-utils + curl are required by the Nix installer.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils sudo bash \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching the container UID/GID enforced by main.tf.
RUN useradd --create-home --uid 1000 --shell /bin/bash coder

# Enable flakes globally before any nix command runs (read by single-user nix too).
RUN mkdir -p /etc/nix \
 && printf 'experimental-features = nix-command flakes\n' > /etc/nix/nix.conf

# Pre-create the Nix store owned by coder so the single-user installer needs no sudo.
RUN mkdir -m 0755 /nix && chown coder:coder /nix

# Code-server installs as root to /usr/bin/code-server (main.tf startup_script
# calls that exact path).
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Pre-create coder's xdg directories owned by coder.
# Some Debian postinst scripts create /home/coder/.cache as root,
# which breaks nix profile install (permission denied).
RUN mkdir -p /home/coder/.cache /home/coder/.local/share \
    && chown -R coder:coder /home/coder/.cache /home/coder/.local

# Everything below runs as the non-root coder user.
USER coder
WORKDIR /home/coder

# Single-user Nix install (no daemon). /nix is already coder-owned.
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add

# Install direnv + nix-direnv into coder's nix profile.
RUN . /home/coder/.nix-profile/etc/profile.d/nix.sh \
 && nix profile install nixpkgs#direnv nixpkgs#nix-direnv

# Wire the interactive shell: source Nix, hook direnv, source nix-direnv's direnvrc.
RUN mkdir -p /home/coder/.config/direnv \
 && printf 'source %s/.nix-profile/share/nix-direnv/direnvrc\n' "$HOME" \
      > /home/coder/.config/direnv/direnvrc \
 && printf '\n# --- Nix + direnv (added by image) ---\nif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi\nexport PATH="$HOME/.nix-profile/bin:$PATH"\neval "$(direnv hook bash)"\n' \
      >> /home/coder/.bashrc

# Direnv VS Code extension removed — causes "Cannot read properties of undefined"
# with VS Code 1.125+. Direnv still works in terminal via .bashrc.
RUN mkdir -p /home/coder/.local/share/code-server/User \
 && printf '{\n  "direnv.restart.automatic": true\n}\n' \
      > /home/coder/.local/share/code-server/User/settings.json

# Make sure the workspace mount point exists (matches main.tf startup_script).
RUN mkdir -p /home/coder/workspace

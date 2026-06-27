#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# add-dev.sh — Add a new developer to the multi-dev container setup
# ─────────────────────────────────────────────────────────────────────
# Usage:  make devbox-add DEV=jane   (or: ./scripts/add-dev.sh jane)
#
# Creates .env.<name> from .env.example. Each developer needs:
#   - Their own Tailscale pre-auth key
#   - Their own SSH public key (added to SSH_PUBLIC_KEYS in .env)
#
# Connect:  ssh coder@devbox-<name>
# Browser:  http://<tailscale-ip>:13337
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <dev-short-name>"
  echo ""
  echo "Creates a .env.<name> from .env.example and prints"
  echo "the commands to build and start that developer's stack."
  echo ""
  echo "Example: $0 jane"
  exit 1
fi

DEV_USER="$1"
COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${COMPOSE_DIR}/.env.${DEV_USER}"

if [ -f "$ENV_FILE" ]; then
  echo "  ⚠ ${ENV_FILE} already exists — edit it directly to update values."
else
  cp "${COMPOSE_DIR}/.env.example" "$ENV_FILE"
  echo "  ✓ Created ${ENV_FILE}"
fi

echo ""
echo "  ──────────────────────────────────────────────────────────"
echo "  Next steps for ${DEV_USER}:"
echo ""
echo "  1. Edit ${ENV_FILE}"
echo "     - Set DEV_USER=\"${DEV_USER}\""
echo "     - Set GIT_USER_NAME and GIT_USER_EMAIL"
echo "     - Set TS_AUTH_KEY (create one per developer in Tailscale admin)"
echo "     - Set SSH_PUBLIC_KEYS to your SSH public key for access"
echo ""
echo "  2. Build and start both containers:"
echo ""
echo "     make devbox-build DEV=${DEV_USER}"
echo "     make devbox-up DEV=${DEV_USER}"
echo ""
echo "     Or directly:"
echo "     docker compose -f ${COMPOSE_DIR}/docker-compose.yml \\"
echo "       --env-file ${ENV_FILE} -p devbox-${DEV_USER} up -d --build"
echo ""
echo "  3. Connect:"
echo ""
echo "     tailscale ip -4 devbox-${DEV_USER}"
echo "     ssh coder@<that-tailscale-ip>"
echo ""
echo "     Or with MagicDNS:"
echo "     ssh coder@devbox-${DEV_USER}"
echo ""
echo "     Browser IDE:"
echo "     http://<tailscale-ip>:13337"
echo ""
echo "  4. Add the container's SSH public key to Git hosts:"
echo ""
echo "     docker compose -f ${COMPOSE_DIR}/docker-compose.yml \\"
echo "       --env-file ${ENV_FILE} -p devbox-${DEV_USER} \\"
echo "       exec devbox cat /home/coder/.ssh/id_ed25519.pub"
echo ""
echo "  ──────────────────────────────────────────────────────────"

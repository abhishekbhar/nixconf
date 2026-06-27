# Multi-host Nix configuration
# Usage: make <hostname>  (e.g., make mini, make wsl, make vajra)

SHELL := /run/current-system/sw/bin/bash
export PATH := /run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$(PATH)

# ── Per-host targets ────────────────────────────────────────────
mini:
	home-manager switch --flake .#mini -b backup

wsl-home:
	home-manager switch --flake .#wsl -b backup

wsl-system:
	sudo nixos-rebuild switch --flake .#wsl

wsl: wsl-system wsl-home

vajra-home:
	home-manager switch --flake .#vajra -b backup

vajra-system:
	sudo nixos-rebuild switch --flake .#vajra

vajra: vajra-system vajra-home

# ── Dev container (multi-developer) ─────────────────────────────
# Each developer runs:  make devbox-up DEV=<name>
# See devcontainer/README.md for full instructions.

COMPOSE_FLAGS = -f devcontainer/docker-compose.yml --env-file devcontainer/.env.$(DEV)
PROJECT_FLAGS  = -p devbox-$(DEV)
DEV ?= abhishek

.PHONY: devbox devbox-build devbox-up devbox-down devbox-logs devbox-shell devbox-add

devbox-build:
	docker compose $(COMPOSE_FLAGS) $(PROJECT_FLAGS) build

devbox-up:
	docker compose $(COMPOSE_FLAGS) $(PROJECT_FLAGS) up -d

devbox-down:
	docker compose $(COMPOSE_FLAGS) $(PROJECT_FLAGS) down

devbox-logs:
	docker compose $(COMPOSE_FLAGS) $(PROJECT_FLAGS) logs -f

devbox-shell:
	docker compose $(COMPOSE_FLAGS) $(PROJECT_FLAGS) exec devbox bash

devbox-rebuild: devbox-build devbox-up
	@echo ""
	@echo "devbox-$(DEV) rebuilt and started."
	@echo "Connect: ssh coder@devbox-$(DEV)  (or tailscale ip -4 devbox-$(DEV))"

devbox-add:
	@test -n "$(DEV)" || (echo "Usage: make devbox-add DEV=jane" && exit 1)
	devcontainer/scripts/add-dev.sh $(DEV)

# Convenience: make devbox-up (uses DEV=abhishek by default)
devbox:
	$(MAKE) devbox-up DEV=$(DEV)

# ── Utilities ───────────────────────────────────────────────────
update:
	nix flake update

gc:
	nix-collect-garbage --delete-older-than 7d || true
	sudo nix-collect-garbage --delete-older-than 7d || true

check:
	nix flake check

clean:
	rm -rf result

# Show available targets
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Hosts:"
	@echo "    mini         - Build Home Manager for mini (macOS)"
	@echo "    wsl          - Build NixOS system + Home Manager for wsl"
	@echo "    wsl-system   - Build NixOS system only for wsl"
	@echo "    wsl-home     - Build Home Manager only for wsl"
	@echo "    vajra        - Build NixOS system + Home Manager for vajra"
	@echo "    vajra-system - Build NixOS system only for vajra"
	@echo "    vajra-home   - Build Home Manager only for vajra"
	@echo ""
	@echo "  Utilities:"
	@echo "    update       - Update flake inputs"
	@echo "    gc           - Run garbage collection"
	@echo "    check        - Check flake configuration"
	@echo "    clean        - Remove build artifacts"

.PHONY: mini wsl wsl-home wsl-system vajra vajra-home vajra-system update gc check clean help

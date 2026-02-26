# Simplified Makefile for multi-platform Nix configurations

USER_NAME := abhishekbhar

# Main targets for complete system builds
wsl:
	sudo nixos-rebuild switch --flake .#wsl

home:
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		echo "Detected macOS – using Home Manager config for mac"; \
		home-manager switch --flake .#home -b backup; \
	else \
		echo "Detected Linux/WSL – using Home Manager config"; \
		home-manager switch --flake .#home -b backup; \
	fi

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
	@echo "  wsl    - Build complete WSL system (NixOS + Home Manager)"
	@echo "  home   - Build Home Manager only (auto-detects system)"
	@echo "  update - Update flake inputs"
	@echo "  gc     - Run garbage collection"
	@echo "  check  - Check flake configuration"
	@echo "  clean  - Remove build artifacts"

.PHONY: wsl home update gc check clean help

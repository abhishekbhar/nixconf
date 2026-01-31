# Simplified Makefile for multi-platform Nix configurations

# Main targets for complete system builds
wsl:
	sudo nixos-rebuild switch --flake .#wsl

home:
	home-manager switch --flake .#home -b backup

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
	@echo "  mac    - Build complete macOS system (nix-darwin + Home Manager)"
	@echo "  home   - Build Home Manager only (auto-detects system)"
	@echo "  update - Update flake inputs"
	@echo "  gc     - Run garbage collection"
	@echo "  check  - Check flake configuration"
	@echo "  clean  - Remove build artifacts"

.PHONY: wsl mac home hm update gc check clean help

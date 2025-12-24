# VAriables - Update these to match your vars.nix settings
SYSTEM_NAME ?= nixos
USER_NAME ?= abhishekbhar

# Main targets
nixos:
	sudo nixos-rebuild switch --flake .#$(SYSTEM_NAME) && home-manager switch --flake .#$(USER_NAME) -b backup

hm:
	home-manager switch --flake .#$(USER_NAME) -b backup


# Additional helpful targets
update:
	nix flake update

gc:
	sudo nix-collect-garbage -d

check:
	nix flake check

clean:
	rm -rf result

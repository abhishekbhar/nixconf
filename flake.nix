{
  description = "My NixOs + Home Manager (WSL) config";
  
  inputs = {
  	nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  	latestpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  	nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

	home-manager = {
	  url = "github:nix-community/home-manager";
	  inputs.nixpkgs.follows = "nixpkgs";
	};

	nixos-wsl = {
	  url = "github:nix-community/NixOS-WSL";
	  inputs.nixpkgs.follows = "nixpkgs";
	};
  };

  outputs = {
    self,
    nixpkgs,
    latestpkgs,
    nixpkgs-stable,
    home-manager,
    nixos-wsl,
    ...
  } @ inputs:
  let
    inherit (self) outputs;

    # Define the systems we target
    systems = {
      wsl = "x86_64-linux";
      mac = "aarch64-darwin";
    };

    vars = import ./vars.nix;

    # Per-system package sets
    pkgs-stable-wsl = nixpkgs-stable.legacyPackages.${systems.wsl};
    pkgs-latest-wsl = import latestpkgs {
      system = systems.wsl;
      config.allowUnfree = true;
    };

    pkgs-stable-mac = nixpkgs-stable.legacyPackages.${systems.mac};
    pkgs-latest-mac = import latestpkgs {
      system = systems.mac;
      config.allowUnfree = true;
    };
  in
  {
    homeConfigurations = {
      # Existing WSL / Linux Home Manager configuration (kept intact)
      ${vars.os_user} = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${systems.wsl};
        extraSpecialArgs = {
          inputs = inputs;
          outputs = outputs;
          system = systems.wsl;
          vars = vars;
          pkgs-stable = pkgs-stable-wsl;
          pkgs-latest = pkgs-latest-wsl;
        };
        modules = [ ./home ];
      };

      # New macOS Home Manager configuration for this MacBook
      "${vars.os_user}-mac" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${systems.mac};
        extraSpecialArgs = {
          inputs = inputs;
          outputs = outputs;
          system = systems.mac;
          vars = vars;
          pkgs-stable = pkgs-stable-mac;
          pkgs-latest = pkgs-latest-mac;
        };
        modules = [ ./home ];
      };
    };

    # NixOS WSL system configuration (Linux-only, unchanged in behaviour)
    nixosConfigurations.${vars.system_name} = nixpkgs.lib.nixosSystem {
      system = systems.wsl;
      specialArgs = { inherit vars; };
      modules = [
        # Enable WSL support
        nixos-wsl.nixosModules.wsl

        # Main system config
        ./os/configuration.nix

        # Enable flakes, unfree, and Home Manager integrations
        {
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.config.allowUnfree = true;
        }
      ];
    };
  };
}

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
  } @ inputs : let 
	inherit (self) outputs;
	system = "x86_64-linux";
	vars = import ./vars.nix;
	pkgs-stable = nixpkgs-stable.lagacyPackages.${system};
	pkgs-latest = import latestpkgs {
	  inherit system;
	  config.allowUnfree = true;
	};
	in {
	  homeConfigurations = {
		${vars.os_user} = home-manager.lib.homeManagerConfiguration {
		  pkgs = nixpkgs.legacyPackages.${system};
		  extraSpecialArgs = {
			inherit inputs outputs system vars pkgs-stable pkgs-latest;
		  };
		  modules = [./home];
		};
	  };

	  nixosConfigurations.${vars.system_name} = nixpkgs.lib.nixosSystem {
		inherit system;
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

{
  description = "My NixOS + Home Manager + nix-darwin config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    mostlatestpkgs.url = "github:nixos/nixpkgs/master";
    latestpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      vars = import ./vars.nix;

      # Detect current system
      currentSystem =
        if inputs.nixpkgs.legacyPackages.aarch64-darwin.stdenv.isDarwin or false then
          "aarch64-darwin"
        else
          "x86_64-linux";

      # Helper to create specialArgs for each profile
      mkSpecialArgs = system: inputs // { inherit inputs vars system; };

      # Helper to create base modules
      mkBaseModules =
        modules:
        modules
        ++ [
          {
            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
            nixpkgs.config.allowUnfree = true;
          }
        ];
    in
    {
      # WSL NixOS configuration
      nixosConfigurations.wsl = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = mkSpecialArgs "x86_64-linux";
        modules = mkBaseModules [
          inputs.nixos-wsl.nixosModules.wsl
          ./wsl/configuration.nix
        ];
      };

      # Home Manager configuration
      homeConfigurations.home = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${currentSystem};
        extraSpecialArgs = mkSpecialArgs currentSystem // {
          latestpkgs = import inputs.latestpkgs {
            system = currentSystem;
            config.allowUnfree = true;
          };
          mostlatestpkgs = import inputs.mostlatestpkgs {
            system = currentSystem;
            config.allowUnfree = true;
          };
        };
        modules = [
          ./home
        ];
      };
    };
}

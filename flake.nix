{
  description = "Multi-host NixOS + Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    mostlatestpkgs.url = "github:nixos/nixpkgs/master";

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

      # ── Host definitions ──────────────────────────────────────────
      # Add a new host by adding an entry here and creating hosts/<name>/
      hosts = {
        mini = {
          system = "aarch64-darwin";
          isNixOS = false;
        };
        wsl = {
          system = "x86_64-linux";
          isNixOS = true;
          nixosModules = [
            inputs.nixos-wsl.nixosModules.wsl
            ./hosts/wsl/system.nix
          ];
        };
        vajra = {
          system = "x86_64-linux";
          isNixOS = true;
          nixosModules = [
            ./hosts/vajra/system.nix
          ];
        };
      };

      # ── Helpers ───────────────────────────────────────────────────
      mkSpecialArgs = system: {
        inherit inputs vars system;
      };

      mkExtraPkgs = system: {
        mostlatestpkgs = import inputs.mostlatestpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      };

      mkHome =
        name: hostCfg:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${hostCfg.system};
          extraSpecialArgs = mkSpecialArgs hostCfg.system // mkExtraPkgs hostCfg.system;
          modules = [
            ./hosts/${name}
          ];
        };

      mkNixOS =
        name: hostCfg:
        lib.nixosSystem {
          system = hostCfg.system;
          specialArgs = mkSpecialArgs hostCfg.system;
          modules = hostCfg.nixosModules ++ [
            {
              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];
              nixpkgs.config.allowUnfree = true;
            }
          ];
        };

      # Filter hosts by attribute
      nixosHosts = lib.filterAttrs (_: cfg: cfg.isNixOS) hosts;
    in
    {
      # Generate homeConfigurations for every host
      homeConfigurations = lib.mapAttrs mkHome hosts;

      # Generate nixosConfigurations for NixOS hosts only
      nixosConfigurations = lib.mapAttrs mkNixOS nixosHosts;
    };
}

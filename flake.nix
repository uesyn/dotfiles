{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-24.11";
    };
    nix-ld.url = "github:Mic92/nix-ld";
    nixos-wsl = {
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      url = "github:nix-community/NixOS-WSL";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nix-ld,
    nixos-wsl,
    ...
  }: let
    nixpkgsConfig = {
      allowUnfree = true;
    };

    nixpkgsUnstableOverlay = final: prev: {
      unstable = import nixpkgs-unstable {
        system = "${prev.system}";
        config = nixpkgsConfig;
      };
    };

    defaultOverlays = [
      nixpkgsUnstableOverlay
    ];
  in
    {
      lib = let
        defaultArgs = {
          additionalPackages = pkgs: [];
          go = {
            private = [];
          };
          git = {
            user = "uesyn";
            email = "17411645+uesyn@users.noreply.github.com";
          };
          git-credential-oauth = {
            device = false;
            ghHosts = [];
          };
        };
      in {
        forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

        homeManagerConfiguration = {
          system,
          user ? builtins.getEnv "USER",
          homeDirectory ? builtins.getEnv "HOME",
          additionalOverlays ? [],
          args ? {},
        }: {
          ${user} = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config = nixpkgsConfig;
              overlays = additionalOverlays ++ defaultOverlays;
            };
            extraSpecialArgs = nixpkgs.lib.attrsets.recursiveUpdate defaultArgs args;

            modules = [
              {
                home.username = user;
                home.homeDirectory = homeDirectory;
              }
              ./home-manager/default.nix
            ];
          };
        };

        # For nixos running on wsl2
        wslNixosConfigurations = {
          system,
          additionalOverlays ? [],
        }: {
          "wsl2" = nixpkgs.lib.nixosSystem {
            inherit system;

            modules = [
              {
                nixpkgs.config = nixpkgsConfig;
                nixpkgs.overlays = additionalOverlays ++ defaultOverlays;
              }
              nix-ld.nixosModules.nix-ld
              nixos-wsl.nixosModules.default
              ./hosts/linux/wsl2.nix
            ];
          };
        };
      };
    }
    // {
      packages = self.lib.forAllSystems (system: {
        # For standalone home-manager
        homeConfigurations = self.lib.homeManagerConfiguration {
          inherit system;
        };

        # For nixos running on wsl2
        nixosConfigurations = self.lib.wslNixosConfigurations {
          inherit system;
        };
      });

      devShells = self.lib.forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
          overlays = defaultOverlays;
        };
      in {
        default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.curl
            pkgs.home-manager
          ];
        };
      });

      templates = {
        default = {
          path = ./templates;
          description = "dotfiles configuration";
        };
      };

      formatter = self.lib.forAllSystems (system: let
        pkgs = import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
        };
      in
        pkgs.alejandra);
    };
}

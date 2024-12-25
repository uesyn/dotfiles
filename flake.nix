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
    nix-ld = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/nix-ld";
    };
    nixos-wsl = {
      inputs.nixpkgs.follows = "nixpkgs";
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

    nixpkgsUnstableOverlay = system: (
      final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config = nixpkgsConfig;
        };
      }
    );
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
            hosts = [];
          };
        };
      in {
        forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

        homeManagerConfiguration = {
          system,
          user ? builtins.getEnv "USER",
          homeDirectory ? builtins.getEnv "HOME",
          additionalOverlays ? [],
          args ? defaultArgs,
        }: {
          ${user} = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config = nixpkgsConfig;
              overlays = additionalOverlays ++ [(nixpkgsUnstableOverlay system)];
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
                wsl.enable = true;
                nixpkgs.config = nixpkgsConfig;
                nixpkgs.overlays = additionalOverlays ++ [(nixpkgsUnstableOverlay system)];
              }
              nix-ld.nixosModules.nix-ld
              nixos-wsl.nixosModules.default
              ./hosts/linux/default.nix
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
          overlays = [(nixpkgsUnstableOverlay system)];
        };
      in {
        default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.curl
            pkgs.home-manager
          ];
        };

        rust = pkgs.mkShell {
          packages = [
            pkgs.openssl
            pkgs.pkg-config
          ];
        };

        go_1_22 = pkgs.mkShell {
          packages = [
            pkgs.go_1_22
          ];
        };

        python3 = pkgs.mkShell {
          packages = [
            pkgs.python3
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

{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
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
    home-manager,
    nix-ld,
    nixos-wsl,
    ...
  }: let
    nixpkgsConfig = {
      allowUnfree = true;
    };

    nixpkgsOverlays = [
      # (final: prev: {
      #   tmux = pkgs-pinned.tmux;
      #   tmuxPlugins = pkgs-pinned.tmuxPlugins;
      # })
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
            hosts = [];
          };
        };
      in {
        forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

        homeManagerConfiguration = {
          system,
          user ? builtins.getEnv "USER",
          homeDirectory ? builtins.getEnv "HOME",
          args ? defaultArgs,
        }: {
          ${user} = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config = nixpkgsConfig;
              overlays = nixpkgsOverlays;
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
          target ? "wsl2",
          args ? defaultArgs,
        }: {
          ${target} = nixpkgs.lib.nixosSystem {
            inherit system;

            specialArgs = {
              extraSpecialArgs = nixpkgs.lib.attrsets.recursiveUpdate defaultArgs args;
            };

            modules = [
              {
                wsl.enable = true;
                nixpkgs.config = nixpkgsConfig;
                nixpkgs.overlays = nixpkgsOverlays;
              }
              home-manager.nixosModules.home-manager
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
          overlays = nixpkgsOverlays;
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
          overlays = nixpkgsOverlays;
        };
      in
        pkgs.alejandra);
    };
}

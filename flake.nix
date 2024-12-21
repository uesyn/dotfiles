{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
    flake-utils,
    nix-ld,
    nixos-wsl,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        currentUsername = builtins.getEnv "USER";
        currentHomeDirectory = builtins.getEnv "HOME";
        defaultArgs = {
          gitUser = "uesyn";
          gitEmail = "17411645+uesyn@users.noreply.github.com";
          gitHosts = [];
        };
      in {
        lib =
          let
            # TODO: Use Same configuration with home-manager and nixos
            pkgs = {system}:
              import nixpkgs {
                inherit system;
                config = {allowUnfree = true;};
                overlays = [
                  # (final: prev: {
                  #   tmux = pkgs-pinned.tmux;
                  #   tmuxPlugins = pkgs-pinned.tmuxPlugins;
                  # })
                ];
              };
          in
          {
          homeConfigurations = {
            system,
            user,
            homeDirectory,
            args ? defaultArgs,
          }:
          {
            ${user} = home-manager.lib.homeManagerConfiguration {
              pkgs = pkgs {inherit system;};
              extraSpecialArgs = args;

              modules = [
                {
                  home.username = user;
                  home.homeDirectory = homeDirectory;
                }
                ./home-manager
              ];
            };
          };

          # For nixos running on wsl2
          wslNixosConfigurations = {
            system,
            args ? defaultArgs,
          }:
            nixpkgs.lib.nixosSystem {
              inherit system;
          
              specialArgs = {
                extraSpecialArgs = defaultArgs;
              };
          
              modules = [
                home-manager.nixosModules.home-manager
                nix-ld.nixosModules.nix-ld
                nixos-wsl.nixosModules.default
                ./hosts/wsl2
              ];
            };
        };

        packages = {
          homeConfigurations = {
            # For standalone home-manager
            "${currentUsername}" = self.lib.${system}.homeManagerConfiguration {
              inherit system;
              user = "${currentUsername}";
              homeDirectory = "${currentHomeDirectory}";
            };
          };
          nixosConfigurations = {
            # For nixos running on wsl2
            wsl2 = self.lib.${system}.wslNixosConfigurations {
              inherit system;
            };
          };
        };

        # devShells = {
        #   default = pkgs.mkShell {
        #     packages = [
        #       pkgs.git
        #       pkgs.curl
        #       pkgs.home-manager
        #     ];
        #   };

        #   rust = pkgs.mkShell {
        #     packages = [
        #       pkgs.openssl
        #       pkgs.pkg-config
        #     ];
        #   };

        #   go_1_22 = pkgs.mkShell {
        #     packages = [
        #       pkgs.go_1_22
        #     ];
        #   };

        #   python3 = pkgs.mkShell {
        #     packages = [
        #       pkgs.python3
        #     ];
        #   };
        # };

        # formatter = pkgs.alejandra;
      }
    ) // {
      # re-export the inputs
      nixpkgs = nixpkgs;
      nix-ld = nix-ld;
      nixos-wsl = nixos-wsl;
      home-manager = home-manager;
    };
}

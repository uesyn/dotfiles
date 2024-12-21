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
    {
      lib = let
        defaultUser = builtins.getEnv "USER";
        defaultHomeDirectory = builtins.getEnv "HOME";
        defaultArgs = {
          gitUser = "uesyn";
          gitEmail = "17411645+uesyn@users.noreply.github.com";
          gitHosts = [];
        };
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
            system ? builtins.currentSystem,
            user ? defaultUser,
            homeDirectory? defaultHomeDirectory,
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
          target ? "wsl2",
          system ? builtins.currentSystem,
          args ? defaultArgs,
        }:
        {
          ${target} = nixpkgs.lib.nixosSystem {
            inherit system;
        
            specialArgs = {
              extraSpecialArgs = args;
            };
        
            modules = [
              home-manager.nixosModules.home-manager
              nix-ld.nixosModules.nix-ld
              nixos-wsl.nixosModules.default
              ./hosts/wsl2
            ];
          };
        };
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (
      system: {
        packages = {
          # For standalone home-manager
          homeConfigurations = self.lib.homeManagerConfiguration {
              inherit system;
          };
          # For nixos running on wsl2
          nixosConfigurations = self.lib.wslNixosConfigurations {
              inherit system;
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
    );
}

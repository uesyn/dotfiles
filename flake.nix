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
    nixpkgs,
    home-manager,
    flake-utils,
    nix-ld,
    nixos-wsl,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [
          # (final: prev: {
          #   tmux = pkgs-pinned.tmux;
          #   tmuxPlugins = pkgs-pinned.tmuxPlugins;
          # })
        ];
        pkgs = import nixpkgs {
          inherit system;
          config = {allowUnfree = true;};
          overlays = overlays;
        };
        currentUsername = builtins.getEnv "USER";
        currentHomeDirectory = builtins.getEnv "HOME";
        extraSpecialArgs = {
          gitUser = "uesyn";
          gitEmail = "17411645+uesyn@users.noreply.github.com";
          gitHosts = [];
        };
      in {
        # For standalone home-manager
        packages.homeConfigurations = {
          "${currentUsername}" = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            inherit extraSpecialArgs;

            modules = [
              {
                home.username = currentUsername;
                home.homeDirectory = currentHomeDirectory;
              }
              ./home-manager
            ];
          };
        };

        # For nixos running on wsl2
        packages.nixosConfigurations = {
          wsl2 = nixpkgs.lib.nixosSystem {
            inherit system;

            specialArgs =  {
              extraSpecialArgs = extraSpecialArgs;
            };

            modules = [
              home-manager.nixosModules.home-manager
              nix-ld.nixosModules.nix-ld
              nixos-wsl.nixosModules.default
              ./hosts/wsl2
            ];
          };
        };

        formatter = pkgs.alejandra;
      }
    );
}

{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-24.11";
    };
    nixos-wsl = {
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      url = "github:nix-community/NixOS-WSL";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nixos-wsl,
    ...
  }: let
    lib = import ./lib {
      inherit nixpkgs;
      inherit nixpkgs-unstable;
      inherit home-manager;
      inherit nixos-wsl;
    };
    systemMap = {
      aarch64Darwin = "aarch64-darwin"; # 64-bit ARM macOS
      aarch64Linux = "aarch64-linux"; # 64-bit ARM Linux
      x86_64Darwin = "x86_64-darwin"; # 64-bit x86 macOS
      x86_64Linux = "x86_64-linux"; # 64-bit x86 Linux
    };
  in {
    inherit lib;

    packages = {
      ${systemMap.aarch64Darwin} = {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = lib.hm {
            system = systemMap.aarch64Darwin;
          };
        };
      };

      ${systemMap.x86_64Linux} = {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = lib.hm {
            system = systemMap.x86_64Linux;
          };
        };

        nixosConfigurations = {
          "wsl2" = lib.wsl2 {
            system = systemMap.x86_64Linux;
          };
        };
      };
    };

    templates = {
      default = {
        path = ./templates;
        description = "dotfiles configuration";
      };
    };

    formatter =
      nixpkgs.lib.genAttrs [
        "aarch64-darwin" # 64-bit ARM macOS
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit x86 macOS
        "x86_64-linux" # 64-bit x86 Linux
      ] (system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
        pkgs.alejandra);
  };
}

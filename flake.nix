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
    self,
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
    apps = import ./apps {
      dotfilesLib = lib;
    };
    formatter = import ./formatter {
      dotfilesLib = lib;
    };
    packages = import ./packages {
      dotfiles = self;
    };
  in {
    inherit lib;
    inherit apps;
    inherit formatter;
    inherit packages;

    templates = {
      default = {
        path = ./templates;
        description = "dotfiles configuration";
      };
    };
  };
}

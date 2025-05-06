{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-24.11";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    lib = import ./lib {
      inherit nixpkgs;
      inherit home-manager;
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

{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-ai-tools.url = "github:numtide/llm-agents.nix";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, nix-ai-tools, ... }@inputs:
    let
      lib = import ./lib inputs;

      appsForSystem =
        system:
        let
          pkgs = lib.pkgsForSystem { inherit system; overlays = []; };
        in
        {
          hm = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "hm.sh" ''
              #!${pkgs.bash}/bin/bash
              ${pkgs.home-manager}/bin/home-manager switch --flake . --impure -b backup --show-trace
            ''}/bin/hm.sh";
          };
        };

      packagesForSystem = system: {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = lib.hm {
            inherit system;
          };
        };
      };

      formatterForSystem = system: (lib.pkgsForSystem { inherit system; }).nixfmt-tree;

    in
    {
      inherit lib;

      apps = lib.forAllSystems appsForSystem;
      packages = lib.forAllSystems packagesForSystem;
      formatter = lib.forAllSystems formatterForSystem;

      templates = {
        default = {
          path = ./templates;
          description = "dotfiles configuration";
        };
      };
    };
}

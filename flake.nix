{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
    kubebuilder = {
      url = "github:kubernetes-sigs/kubebuilder/v4.13.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      llm-agents,
      ...
    }@inputs:
    let
      lib = {
        forAllSystems = nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];
      };

      formatterForSystem = system: nixpkgs.legacyPackages.${system}.nixfmt-tree;

      appsForSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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

    in
    {
      inherit lib;

      homeManagerModules = {
        default = import ./home-manager self;
      };

      apps = lib.forAllSystems appsForSystem;
      formatter = lib.forAllSystems formatterForSystem;
      packages = lib.forAllSystems (system: {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.${system};
            modules = [
              self.homeManagerModules.default
              {
                home.username = builtins.getEnv "USER";
                home.homeDirectory = builtins.getEnv "HOME";
              }
            ];
          };
        };
      });

      templates = {
        default = {
          path = ./templates;
          description = "dotfiles configuration";
        };
      };
    };
}

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
    in
    {
      inherit lib;

      homeManagerModules = {
        default = import ./home-manager self;
      };

      formatter = lib.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

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

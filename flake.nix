{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    winresize-nvim = {
      url = "github:pogyomo/winresize.nvim";
      flake = false;
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
      lib = import ./lib inputs;

      appsForSystem =
        system:
        let
          pkgs = lib.pkgsForSystem {
            inherit system;
            overlays = [ ];
          };
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

      formatterForSystem = system: (lib.pkgsForSystem { inherit system; }).nixfmt-tree;

    in
    {
      inherit lib;

      overlays = {
        llm-agents = llm-agents.overlays.default;
      };

      homeManagerModules = {
        default = import ./home-manager self;
      };

      apps = lib.forAllSystems appsForSystem;
      formatter = lib.forAllSystems formatterForSystem;
      packages = lib.forAllSystems (system: {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = home-manager.lib.homeManagerConfiguration {
            pkgs = lib.pkgsForSystem {
              inherit system;
              overlays = [ ];
            };
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

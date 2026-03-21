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
    {
      self,
      nixpkgs,
      home-manager,
      nix-ai-tools,
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

      homeConfigurations = {
        ${builtins.getEnv "USER"} = home-manager.lib.homeManagerConfiguration {
          pkgs = lib.pkgsForSystem {
            system = "x86_64-linux";
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

      formatterForSystem = system: (lib.pkgsForSystem { inherit system; }).nixfmt-tree;

    in
    {
      inherit lib;

      overlays = {
        nix-ai-tools = nix-ai-tools.overlays.default;
      };

      homeManagerModules = {
        default = import ./home-manager self;
      };

      apps = lib.forAllSystems appsForSystem;
      formatter = lib.forAllSystems formatterForSystem;
      inherit homeConfigurations;

      templates = {
        default = {
          path = ./templates;
          description = "dotfiles configuration";
        };
      };
    };
}

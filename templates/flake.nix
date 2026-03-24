{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    dotfiles = {
      url = "github:uesyn/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      dotfiles,
      ...
    }:
    {
      packages = dotfiles.lib.forAllSystems (system: {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = home-manager.lib.homeManagerConfiguration {
            pkgs = dotfiles.lib.pkgsForSystem {
              inherit system;
              overlays = [ ];
            };
            modules = [
              dotfiles.homeManagerModules.default
              {
                home.username = builtins.getEnv "USER";
                home.homeDirectory = builtins.getEnv "HOME";
              }
            ];
          };
        };
      });
    };
}

{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ai-tools.url = "github:numtide/llm-agents.nix";

    dotfiles = {
      url = "github:uesyn/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-ai-tools.follows = "nix-ai-tools";
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
      homeConfigurations."${builtins.getEnv "USER"}" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit dotfiles;
        };
        modules = [
          dotfiles.homeManagerModules.default
          ./home.nix
        ];
      };
    };
}

{
  description = "dotfiles configuration";

  inputs = {
    nix-configurations-base.url = "github:uesyn/nix-configurations-base";
    # nixpkgs.follows = "nix-configurations-base/nixpkgs";
    # nixpkgs-unstable.follows = "nix-configurations-base/nixpkgs-unstable";
  };

  outputs = {
    nix-configurations-base,
    ...
  }: let
    overlays = [];
    hmModules = [];
    nixOSModules = [];
    hmArgs = {
      go = {
        private = [];
      };
      git = {
        user = "uesyn";
        email = "17411645+uesyn@users.noreply.github.com";
      };
      git-credential-oauth = {
        device = false;
        ghHosts = [];
      };
    };
  in {
    packages = nix-configurations-base.lib.forAllSystems (system: {
      homeConfigurations = nix-configurations-base.lib.homeManagerConfiguration {
        inherit overlays;
        inherit system;
        modules = hmModules;
        args = hmArgs;
        # user = "sample";
        # homeDirectory = "/home/sample";
      };

      nixosConfigurations = nix-configurations-base.lib.wslNixosConfigurations {
        inherit overlays;
        inherit system;
        modules = nixOSModules;
      };
    });

    formatter = nix-configurations-base.formatter;
  };
}

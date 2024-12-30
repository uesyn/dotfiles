{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
  };

  outputs = {
    self,
    dotfiles,
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
    packages = dotfiles.lib.forAllSystems (system: {
      homeConfigurations = dotfiles.lib.homeManagerConfiguration {
        inherit overlays;
        inherit system;
        modules = hmModules;
        args = hmArgs;
        user = "sample";
        homeDirectory = "/home/sample";
      };

      nixosConfigurations = dotfiles.lib.wslNixosConfigurations {
        inherit overlays;
        inherit system;
        modules = nixOSModules;
      };
    });

    formatter = dotfiles.formatter;
  };
}

{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
  };

  outputs = {
    self,
    dotfiles,
  }: let
    args = {
      additionalPackages = pkgs: [];
      go = {
        private = [];
      };
      git = {
        user = "uesyn";
        email = "17411645+uesyn@users.noreply.github.com";
      };
      git-credential-oauth = {
        device = false;
        hosts = [];
      };
    };
  in {
    packages = dotfiles.lib.forAllSystems (system: {
      homeConfigurations = dotfiles.lib.homeManagerConfiguration {
        inherit system;
        inherit args;
        user = "sample";
        homeDirectory = "/home/sample";
      };

      nixosConfigurations = dotfiles.lib.wslNixosConfigurations {
        inherit system;
        inherit args;
      };
    });

    formatter = dotfiles.formatter;
  };
}
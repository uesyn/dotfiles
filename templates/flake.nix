{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
  };

  outputs = {
    self,
    dotfiles,
  }: let
    additionalOverlays = [];
    hmAdditionalModules = [];
    nixOSAdditionalModules = [];
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
        ghHosts = [];
      };
    };
  in {
    packages = dotfiles.lib.forAllSystems (system: {
      homeConfigurations = dotfiles.lib.homeManagerConfiguration {
        inherit additionalOverlays;
        additionalModules = hmAdditionalModules;
        inherit args;
        inherit system;
        user = "sample";
        homeDirectory = "/home/sample";
      };

      nixosConfigurations = dotfiles.lib.wslNixosConfigurations {
        inherit additionalOverlays;
        additionalModules = nixOSAdditionalModules;
        inherit args;
        inherit system;
      };
    });

    formatter = dotfiles.formatter;
  };
}

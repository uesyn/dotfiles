{dotfiles}:
dotfiles.lib.forAllSystems (system: {
  homeConfigurations = {
    ${builtins.getEnv "USER"} = dotfiles.lib.hm {
      inherit system;
      # user = builtins.getEnv "USER";
      # homeDirectory = builtins.getEnv "HOME";
      # modules = [];
      # overlays = [];
      # extraSpecialArgs = {};
    };
  };

  nixosConfigurations = {
    "wsl2" = dotfiles.lib.wsl2 {
      inherit system;
      # overlays = [];
      # modules = [];
    };
  };
})

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
})

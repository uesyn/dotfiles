{dotfiles}:
dotfiles.lib.forAllSystems (system: {
  homeConfigurations = {
    ${builtins.getEnv "USER"} = dotfiles.lib.hm {
      inherit system;
      # user = builtins.getEnv "USER";
      # homeDirectory = builtins.getEnv "HOME";
      # modules = [];
      # overlays = [];
      # extraSpecialArgs = {
      #   go = {
      #     private = [];
      #   };
      #   git = {
      #     user = "uesyn";
      #     email = "17411645+uesyn@users.noreply.github.com";
      #   };
      #   git-credential-oauth = {
      #     device = false;
      #     ghHosts = [];
      #   };
      # };
    };
  };
})

{
  nixpkgs,
  dotfiles,
}: let
  supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
in
  forAllSystems (system: {
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

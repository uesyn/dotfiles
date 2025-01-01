{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
  };

  outputs = {dotfiles, ...}: let
    systemMap = {
      aarch64Darwin = "aarch64-darwin"; # 64-bit ARM macOS
      aarch64Linux = "aarch64-linux"; # 64-bit ARM Linux
      x86_64Darwin = "x86_64-darwin"; # 64-bit x86 macOS
      x86_64Linux = "x86_64-linux"; # 64-bit x86 Linux
    };
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
    packages = {
      ${systemMap.aarch64Darwin} = {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = dotfiles.lib.hm {
            inherit overlays;
            system = systemMap.aarch64Darwin;
            modules = hmModules;
            extraSpecialArgs = hmArgs;
          };
        };
      };

      ${systemMap.x86_64Linux} = {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = dotfiles.lib.hm {
            inherit overlays;
            system = systemMap.x86_64Linux;
            modules = hmModules;
            extraSpecialArgs = hmArgs;
            # user = "nixos";
            # homeDirectory = "/home/nixos";
          };
        };

        nixosConfigurations = {
          "wsl2" = dotfiles.lib.wsl2 {
            inherit overlays;
            system = systemMap.x86_64Linux;
            modules = nixOSModules;
          };
        };
      };
    };

    formatter = dotfiles.formatter;
  };
}

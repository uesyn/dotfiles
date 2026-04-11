{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.fence = {
    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Allowed domains for network access in fence.";
    };
    allowedUnixSockets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Allowed unix sockets for network access in fence.";
    };
    deniedCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Denied commands for network access in fence.";
    };
  };

  config =
  let
    allowedDomains = builtins.toJSON config.dotfiles.fence.allowedDomains;
    allowedUnixSockets = builtins.toJSON config.dotfiles.fence.allowedUnixSockets;
    deniedCommands = builtins.toJSON config.dotfiles.fence.deniedCommands;
    isLinux = pkgs.stdenv.hostPlatform.isLinux;
  in
    {
      home.packages = [
        pkgs.fence
      ]
      ++ lib.optionals isLinux [
        pkgs.bubblewrap
        pkgs.bpftrace
      ] ;
      xdg.configFile = {
        "fence/fence.json".text = ''
          {
            "$schema": "https://raw.githubusercontent.com/Use-Tusk/fence/main/docs/schema/fence.schema.json",
            "extends": "./base.json",
            "command": {
              "deny": ${deniedCommands},
            },
            "network": {
              "allowedDomains": ${allowedDomains},
              "allowUnixSockets": ${allowedUnixSockets},
            },
          }
        '';
        "fence/base.json".text = ''
          {
            "$schema": "https://raw.githubusercontent.com/Use-Tusk/fence/main/docs/schema/fence.schema.json",
            "extends": "code",
            "network": {
              "allowedDomains": [
                // MiniMax
                "*.minimax.io",
                "*.exa.ai",

                // Sakura Internet
                "*.sakura.ad.jp",

                // Go
                "*.pkg.go.dev"
              ],
              "allowUnixSockets": [
                // Colima
                "~/.colima/docker.sock",
                "~/.colima/default/docker.sock"
              ]
            },
            "filesystem": {
              "allowExecute": [
                "/nix/store/**"
              ],
              "allowWrite": [
                // Go
                "~/pkg/**"
              ]
            },
            "command": {
              "acceptSharedBinaryCannotRuntimeDeny": [
                "chroot"
              ]
            }
          }
        '';
      };
    };
}

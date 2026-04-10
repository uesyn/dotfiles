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
  in
    {
      home.packages = [
        pkgs.fence
      ];
      xdg.configFile = {
        "fence/fence.json".text = ''
          {
            "$schema": "https://raw.githubusercontent.com/Use-Tusk/fence/main/docs/schema/fence.schema.json",
            "extends": "code",
            "command": {
              "acceptSharedBinaryCannotRuntimeDeny": [
                "chroot"
              ],
              "deny": ${deniedCommands},
            },
            "network": {
              "allowedDomains": ${allowedDomains},
              "allowUnixSockets": ${allowedUnixSockets},
            },
            "filesystem": {
              "allowExecute": [
              ],
            }
          }
        '';
      };
    };
}

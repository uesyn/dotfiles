{ piWeb }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.pi.pi-web-tailcat.enable = lib.mkEnableOption "pi-web-tailcat";

  # `pi-web-tailcat` exposes pi-web through a tailcat tunnel: `start` runs
  # pi-web with the host allow-list entry clients need plus `tailcat serve`,
  # `stop` takes the tunnel down. Separate transient systemd user services
  # manage both processes; no persistent unit files or namespaces are needed.
  config.home.packages = lib.mkIf (config.dotfiles.pi.pi-web-tailcat.enable && pkgs.stdenv.hostPlatform.isLinux) [
    (pkgs.writeShellApplication {
      name = "pi-web-tailcat";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.tailcat
        pkgs.systemd
        pkgs.util-linux
      ];
      text = builtins.replaceStrings [ "@piWeb@" ] [ (lib.getExe piWeb) ] (
        builtins.readFile ./pi-web-tailcat.sh
      );
    })
  ];
}

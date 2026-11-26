{ piWeb }:
{
  pkgs,
  lib,
  ...
}:
{
  # `pi-web-tailcat` exposes pi-web through a tailcat tunnel: `start` runs
  # pi-web with the host allow-list entry clients need plus `tailcat serve`,
  # `stop` takes the tunnel down. Separate transient systemd user services
  # manage both processes; no persistent unit files or namespaces are needed.
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [
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

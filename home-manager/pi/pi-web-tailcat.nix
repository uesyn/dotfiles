{ pkgs, ... }:
{
  # `pi-web-tailcat` exposes pi-web through a tailcat tunnel: `serve` starts
  # pi-web with the host allow-list entry clients need and runs `tailcat serve`.
  # Clients run `tailcat socks` directly. See the script header for the why.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "pi-web-tailcat";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.tailcat
      ];
      text = builtins.readFile ./pi-web-tailcat.sh;
    })
  ];
}

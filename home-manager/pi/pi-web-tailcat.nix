{ pkgs, ... }:
{
  # `pi-web-tailcat` is the one-command way to reach pi-web from another machine
  # through a tailcat tunnel: `serve` starts pi-web with the host allow-list
  # entry the SOCKS client needs and runs `tailcat serve`, `connect` runs
  # `tailcat socks` on the client. See the script header for the why.
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

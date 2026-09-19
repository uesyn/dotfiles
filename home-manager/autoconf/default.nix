{ pkgs, lib, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
in
{
  home.packages = [ pkgs.autoconf ];

  # nono: `autom4te` execs GNU m4 by absolute store path (`$ENV{M4}` or a
  # hardcoded `/nix/store/...-gnum4.../bin/m4`); m4 is not on PATH, so the
  # Linux outer exec gate must be told about m4's directory. macOS allows all
  # exec.
  dotfiles.nono.commandPolicies.executableDirs = lib.optionals isLinux [
    "${lib.getBin pkgs.gnum4}/bin"
  ];
}

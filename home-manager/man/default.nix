{ pkgs, lib, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
in
{
  # macOS ships its own `/usr/bin/man`, so only add the Nix man on Linux.
  home.packages = lib.optionals isLinux [ pkgs.man-db ];

  # nono: `man` runs helpers (`manconv`, `zsoelim`, `col`) and pipes pages
  # through its wrapped groff/gzip/zstd, none of which are on PATH. macOS
  # allows all exec, so this is Linux-only.
  dotfiles.nono.commandPolicies.executableDirs = lib.optionals isLinux [
    "${pkgs.man-db}/libexec/man-db"
    "${pkgs.util-linuxMinimal.bin}/bin"
    "${pkgs.groff}/bin"
    "${pkgs.gzip}/bin"
    "${pkgs.zstd.bin}/bin"
  ];
}

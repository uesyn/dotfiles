{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dotfiles.buildEssential;

  # `pkg-config` files of the extra `libraries`, so `pkg-config` finds the
  # packages whose libs/headers the prefix exposes (the wrappers already add
  # them to `-L`/`-isystem`).
  pkgConfigPath = lib.concatMap (p: [
    "${lib.getDev p}/lib/pkgconfig"
    "${lib.getDev p}/share/pkgconfig"
    "${lib.getLib p}/lib/pkgconfig"
    "${lib.getLib p}/share/pkgconfig"
  ]) cfg.libraries;
in
{
  home.packages = [ pkgs.pkg-config ];

  home.sessionVariables = lib.mkIf (pkgConfigPath != [ ]) {
    PKG_CONFIG_PATH = lib.concatStringsSep ":" pkgConfigPath;
  };
}

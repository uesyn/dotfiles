{ pkgs, ... }:
{
  home.packages = [ pkgs.tailcat ];

  # nono: saved keys live under `~/.config/tailcat/keys` (read+write, so
  # `genkey` survives the sandbox). The cached DERP map in `~/.cache/tailcat`
  # is already covered by the core `~/.cache` grant.
  dotfiles.nono.filesystem.allow = [ "~/.config/tailcat" ];
}

{ pkgs, ... }:
{
  home.packages = [ pkgs.bun ];

  # nono: `bun install` writes packages under `~/.bun`; writable so installs
  # work and the Tool Sandbox exec grant covers bun's binaries.
  dotfiles.nono.filesystem.allow = [ "~/.bun" ];
}

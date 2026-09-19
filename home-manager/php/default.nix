{ pkgs, ... }:
{
  home.packages = [ pkgs.phpactor ];

  # nono: phpactor keeps its config/data under XDG dirs (the PHP interpreter
  # comes from the script's shebang, which the exec gate adds automatically).
  dotfiles.nono.filesystem.allow = [
    "~/.config/phpactor"
    "~/.local/share/phpactor"
  ];
}

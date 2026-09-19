{
  config,
  pkgs,
  ...
}:
{
  config = {
    # nono: Python installs into the per-user homes below (`pip --user` uses
    # `~/.local/lib`, uv/pyenv/conda their own trees).
    dotfiles.nono.filesystem.allow = [
      "~/.pyenv"
      "~/.local/lib"
      "~/.local/share/uv"
      "~/.conda"
    ];

    home.packages = [
      pkgs.python315
      pkgs.pyright
      pkgs.uv
    ];
  };
}

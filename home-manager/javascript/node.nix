{
  config,
  pkgs,
  ...
}:
{
  # nono: JS toolchain homes (`~/.node` npm prefix and the nvm/fnm/pnpm trees)
  # must be writable for installs and the Tool Sandbox exec grant. (Bun's
  # `~/.bun` is owned by the bun module.)
  dotfiles.nono.filesystem.allow = [
    "~/.npm"
    "~/.node"
    "~/.nvm"
    "~/.fnm"
    "~/.local/share/fnm"
    "~/.local/share/pnpm"
    "~/Library/pnpm"
  ];

  home.file = {
    ".npmrc".text = ''
      prefix=~/.node
    '';
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.node/bin"
  ];

  home.packages = [
    pkgs.nodejs_24
  ];
}

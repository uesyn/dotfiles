{
  pkgs,
  ...
}:
let
  inherit (pkgs) vimPlugins;

  # Loaded on demand by lz.n (see nvim/lua/plugins/). `optional` keeps
  # home-manager from adding them to the startup packpath.
  lazyPlugins = with vimPlugins; [
    baleia-nvim
    barbar-nvim
    blame-nvim
    gitsigns-nvim
    nvim-surround
  ];
in
{
  # nono: read the Neovim config and grant the plugin/state/data dirs.
  dotfiles.nono.filesystem.read = [ "~/.config/nvim" ];
  dotfiles.nono.filesystem.allow = [
    "~/.local/share/nvim"
    "~/.local/state/nvim"
    "~/.local/state/nvim-baleia-bench"
  ];

  xdg.configFile = {
    "nvim" = {
      source = ./nvim;
      recursive = true;
    };
  };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;

    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      bash
      fd
      fzf
      ripgrep
    ];

    # home-manager writes ~/.config/nvim/init.lua, so ./nvim must not contain
    # one. Everything else lives under ./nvim/lua and is required from here.
    initLua = ''
      vim.loader.enable()

      require("config.option")
      require("config.keymap")
      require("config.autocmd")
      require("config.lsp")
      require("config.copilot")
      require("config.statusline")

      require("lz.n").load("plugins")
    '';

    plugins =
      (with vimPlugins; [
        dracula-nvim
        lz-n
        nvim-web-devicons
        snacks-nvim
        (nvim-treesitter.withPlugins (
          p: with p; [
            bash
            c
            go
            json
            lua
            markdown
            markdown_inline
            php
            python
            rust
            toml
            typescript
            yaml
          ]
        ))
      ])
      ++ map (plugin: {
        inherit plugin;
        optional = true;
      }) lazyPlugins;
  };
}

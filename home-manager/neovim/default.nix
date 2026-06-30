{ inputs, pkgs, ... }:
{
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

    initLua = ''
      vim.loader.enable()

      require('keymap')
      require('option')
      require('autocmd')
      require('lsp')
      require('statusline')
      require("lz.n").load("plugins")
    '';

    plugins = with pkgs.vimPlugins; [
      lz-n
      nvim-web-devicons
      plenary-nvim
      nui-nvim
      snacks-nvim
      dracula-nvim
      {
        plugin = (
          pkgs.vimUtils.buildVimPlugin {
            name = "agentic.nvim";
            pname = "agentic.nvim";
            src = inputs.agentic-nvim;
          }
        );
        optional = true;
      }
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
        p.bash
        p.c
        p.go
        p.json
        p.lua
        p.markdown
        p.markdown_inline
        p.php
        p.python
        p.rust
        p.toml
        p.typescript
        p.yaml
      ]))
      {
        plugin = gitsigns-nvim;
        optional = true;
      }
      {
        plugin = barbar-nvim;
        optional = true;
      }
      {
        plugin = nvim-surround;
        optional = true;
      }
      {
        plugin = blame-nvim;
        optional = true;
      }
      {
        plugin = render-markdown-nvim;
        optional = true;
      }
    ];
  };
}

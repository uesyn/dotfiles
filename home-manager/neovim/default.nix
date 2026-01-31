{ pkgs, ... }:
let
  # Use this to create a plugin from a flake input
  mkNvimPlugin =
    name: url: branch: rev:
    let
      pname = "${pkgs.lib.strings.sanitizeDerivationName "${name}"}";
      version = rev;
      src = builtins.fetchGit {
        inherit url;
        ref = branch;
        rev = rev;
      };
    in
    pkgs.vimUtils.buildVimPlugin {
      inherit pname version src;
    };
  winresize-nvim =
    mkNvimPlugin "winresize.nvim" "https://github.com/pogyomo/winresize.nvim.git" "main"
      "a54f4a0dbfd7e52e0e8153325d0c4571e0d33217";
in
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
      require("lz.n").load("plugins")
    '';

    plugins = with pkgs.vimPlugins; [
      lz-n
      nvim-web-devicons
      plenary-nvim
      nui-nvim
      snacks-nvim
      dracula-nvim
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
        p.bash
        p.c
        p.go
        p.javascript
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
      nvim-navic
      lualine-nvim
      {
        plugin = gitsigns-nvim;
        optional = true;
      }
      {
        plugin = fzf-lua;
        optional = true;
      }
      {
        plugin = neo-tree-nvim;
        optional = true;
      }
      {
        plugin = openingh-nvim;
        optional = true;
      }
      {
        plugin = barbar-nvim;
        optional = true;
      }
      {
        plugin = winresize-nvim;
        optional = true;
      }
      {
        plugin = nvim-surround;
        optional = true;
      }
      {
        plugin = hop-nvim;
        optional = true;
      }
      {
        plugin = blame-nvim;
        optional = true;
      }
      {
        plugin = copilot-lua;
        optional = true;
      }
      {
        plugin = CopilotChat-nvim;
        optional = true;
      }
      blink-cmp-copilot
      {
        plugin = blink-cmp;
        optional = true;
      }
      {
        plugin = fidget-nvim;
        optional = true;
      }
      {
        plugin = lsp_lines-nvim;
        optional = true;
      }
      {
        plugin = avante-nvim;
        optional = true;
      }
      { plugin = blink-cmp-avante; }
      {
        plugin = render-markdown-nvim;
        optional = true;
      }
    ];
  };
}

{
  inputs,
  pkgs,
  ...
}:
let 
  mkNvimPlugin = name: url: branch: rev: let
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


  lz-n = mkNvimPlugin "lz.n" "https://github.com/nvim-neorocks/lz.n" "master" "efd583783ef391efe5424c378246ff793f61a2d2";
  blame-nvim = mkNvimPlugin "blame.nvim" "https://github.com/FabijanZulj/blame.nvim.git" "main" "dedbcdce857f708c63f261287ac7491a893912d0";
  nvim-markdown = mkNvimPlugin "nvim-markdown" "https://github.com/ixru/nvim-markdown.git" "master" "75639723c1a3a44366f80cff11383baf0799bcb5";
  cellwidths-nvim = mkNvimPlugin "cellwidths.nvim" "https://github.com/delphinus/cellwidths.nvim.git" "main" "98d8b428020c7e0af098f316a02490e5b37e98da";

  unmanaged-plugins = [
    {
      plugin = blame-nvim;
      optional = true;
    }
    {
      plugin = nvim-markdown;
      optional = true;
    }
    cellwidths-nvim
    lz-n
  ];
  plugins = with pkgs.vimPlugins; [
    # (nvim-treesitter.withPlugins (
    #   plugins:
    #     with plugins; [
    #       markdown
    #       markdown_inline
    #     ]
    # ))
    {
      plugin = dracula-nvim;
      optional = false;
    }
    {
      plugin = plenary-nvim;
      optional = false;
    }
    {
      plugin = nvim-web-devicons;
      optional = false;
    }
    {
      plugin = barbar-nvim;
      optional = true;
    }
    {
      plugin = copilot-vim;
      optional = true;
    }
    {
      plugin = CopilotChat-nvim;
      optional = true;
    }
    {
      plugin = fzf-lua;
      optional = false;
    }
    {
      plugin = gitsigns-nvim;
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
      plugin = nvim-osc52;
      optional = true;
    }
    {
      plugin = nvim-surround;
      optional = true;
    }

    {
      plugin = nvim-lspconfig;
      optional = false;
    }
    {
      plugin = cmp-nvim-lsp;
      optional = false;
    }
    {
      plugin = cmp-nvim-lsp-signature-help;
      optional = false;
    }
    {
      plugin = cmp-snippy;
      optional = false;
    }
    {
      plugin = nvim-snippy;
      optional = false;
    }
    {
      plugin = nvim-cmp;
      optional = true;
    }

    {
      plugin = fidget-nvim;
      optional = true;
    }
    {
      plugin = nvim-navic;
      optional = true;
    }
  ];
  configFile = file: {
    "nvim/${file}".source = pkgs.substituteAll (
      {
        src = ./. + "/${file}";
      }
      # // plugins
    );
  };
  configFiles = files: builtins.foldl' (x: y: x // y) { } (map configFile files);
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;
    extraPackages = with pkgs; [
      bash
      bash-language-server
      fzf
      gopls
      jdt-language-server
      nil # nix LSP
      nodePackages.typescript-language-server
      pyright
      ripgrep
      rust-analyzer
    ];
    extraLuaPackages = ps: [
      ps.tiktoken_core # depended by CopilotChat-nvim
    ];
    plugins = plugins ++ unmanaged-plugins;
  };
  xdg.configFile =
    {
      "nvim/ftdetect".source = ./ftdetect;
      "nvim/ftplugin".source = ./ftplugin;
      "nvim/lua".source = ./lua;
    }
    // configFiles [
      "./init.lua"
      # "./lua/user/options.lua"
      # "./lua/user/plugins/git.lua"
      # "./lua/user/plugins/languages.lua"
      # "./lua/user/plugins/lsp.lua"
      # "./lua/user/plugins/ui.lua"
      # "./lua/user/plugins/utils.lua"
  ];
}

{pkgs, ...}: let
  # Use this to create a plugin from a flake input
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
  blame-nvim = mkNvimPlugin "blame.nvim" "https://github.com/FabijanZulj/blame.nvim.git" "main" "59cf695685c1d8d603d99b246cc8d42421937c09";
  winresize-nvim = mkNvimPlugin "winresize.nvim" "https://github.com/pogyomo/winresize.nvim.git" "main" "a54f4a0dbfd7e52e0e8153325d0c4571e0d33217";
in {
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
      copilot-language-server
    ];

    extraLuaConfig = ''
      vim.loader.enable()

      -- Set up globals
      vim.g["loaded_perl_provider"] = 0
      vim.g["loaded_python_provider"] = 0
      vim.g["loaded_ruby_provider"] = 0
      vim.g["mapleader"] = " "
      vim.g["netrw_fastbrowse"] = 0
      vim.g["clipboard"] = 'osc52'

      -- Set up options
      vim.opt["ambiwidth"] = "single"
      vim.opt["breakindent"] = true
      vim.opt["emoji"] = true
      vim.opt["fileformats"] = { "unix", "dos", "mac" }
      vim.opt["foldcolumn"] = "0"
      vim.opt["inccommand"] = "split"
      vim.opt["laststatus"] = 3
      vim.opt["maxmempattern"] = 20000
      vim.opt["number"] = true
      vim.opt["relativenumber"] = true
      vim.opt["showcmd"] = false
      vim.opt["showmode"] = false
      vim.opt["showtabline"] = 2
      vim.opt["signcolumn"] = "yes"
      vim.opt["synmaxcol"] = 320
      vim.opt["updatetime"] = 100
      vim.opt["wildmode"] = "full"
      vim.opt["termguicolors"] = true
      vim.opt["winborder"] = 'rounded'
      vim.opt["completeopt"] = { 'menu', 'popup', 'noselect' }

      -- keymaps
      vim.keymap.set({"n", "v"}, "<leader>", "<Nop>")
      vim.keymap.set("n", "ZZ", "<Nop>")
      vim.keymap.set("n", "ZQ", "<Nop>")
      vim.keymap.set("n", "q", "<Nop>")
      vim.keymap.set("n", "Q", "<Nop>")

      vim.keymap.set("n", "<S-h>", "<C-w>h")
      vim.keymap.set("n", "<S-j>", "<C-w>j")
      vim.keymap.set("n", "<S-k>", "<C-w>k")
      vim.keymap.set("n", "<S-l>", "<C-w>l")

      -- autocmds
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "qf",
        callback = function()
          vim.bo.buflisted = false
          vim.keymap.set("n", "<C-q>", "<Cmd>clo<CR>", { desc = "Close quickfix", buffer = true })
          vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
          vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
        end,
      })

      -- When yanked, sync system clipboard with OSC52
      vim.api.nvim_create_autocmd('TextYankPost', {
        pattern = '*',
        callback = function()
          event = vim.v.event
          if event.operator == 'y' and event.regname == ''' then
            vim.fn.setreg('+', event.regcontents, event.regtype)
          end
        end,
      })

      -- Language Server Configurations
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local client = vim.lsp.get_client_by_id(args.data.client_id)

          if client:supports_method('textDocument/completion') then
            vim.lsp.completion.enable(true, client.id, args.buf)
          end

          function opts(desc)
            return { desc = desc, noremap = true, silent = true, buffer = bufnr }
          end
          local bufnr = args.buf
          -- vim.keymap.set("n", "gd", function() lua vim.lsp.buf.definition() end, opts("Go to definition"))
          vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, opts("Go to definition"))
          vim.keymap.set("n", "gD", function() Snacks.picker.lsp_declarations() end, opts("Go to declarations"))
          vim.keymap.set("n", "gi", function() Snacks.picker.lsp_implementations() end, opts("Go to implementations"))
          vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts("Displays hover information about the symbol"))
          vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, opts("Go to references")) -- should add nowait option?
          vim.keymap.set("n", "gt", function() Snacks.picker.lsp_type_definitions() end, opts("Go to type defenitions"))
          vim.keymap.set("n", "gs", function() Snacks.picker.lsp_symbols() end, opts("Go to document symbols"))
          vim.keymap.set("i", "<C-l>", function() vim.lsp.buf.signature_help() end, opts("Show signature help"))
          vim.keymap.set("n", "<leader>lR", function() vim.lsp.buf.rename() end, opts("Rename"))
          vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, opts("Format"))
          vim.keymap.set("n", "<leader>la", function() vim.lsp.buf.code_action() end, opts("Format"))
          vim.keymap.set("n", "<leader>li", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, opts("Toggle inlay hint"))
        end,
      })

      vim.lsp.enable({'gopls', 'typescript_language_server', 'rust_analyzer'})
    '';

    plugins = with pkgs.vimPlugins; [
      nvim-web-devicons
      plenary-nvim
      nui-nvim
      nvim-treesitter.withAllGrammars
      {
        plugin = snacks-nvim;
        type = "lua";
        config = ''
          require("snacks").setup({
            explorer = {
              enabled = true,
              replace_netrw = true,
            },
            input = { enabled = true },
            picker = {
              enabled = true,
              formatters = { file = { truncate = 200 } }
            },
            notifier = { enabled = true },
            statuscolumn = { enabled = true },
          })

          -- picker
          vim.keymap.set("n", "<Leader>sg", Snacks.picker.grep, { desc = "Search files with grep and fuzzy finder" })
          vim.keymap.set("n", "<Leader>sf", Snacks.picker.files, { desc = "Search Lines with fuzzy finder" })
          vim.keymap.set("n", "<Leader>s;", Snacks.picker.resume, { desc = "Resume fuzzy finder results" })
          vim.keymap.set("n", "<Leader>sk", Snacks.picker.keymaps, { desc = "Search keymaps" })
          vim.keymap.set("n", "<Leader>sp", function() Snacks.picker() end, { desc = "Resume fuzzy finder results" })

          -- explorer
          vim.keymap.set("n", "<S-f>", function() Snacks.explorer.open() end, { desc = "Open file explorer" })
        '';
      }

      {
        plugin = openingh-nvim;
        type = "lua";
        config = ''
          vim.keymap.set("n", "<Leader>go", "<Cmd>OpenInGHFile<CR>", { desc = "Open in Github" })
          vim.keymap.set("v", "<Leader>go", "<Esc><Cmd>'<,'>OpenInGHFile<CR>", { desc = "Open fucusing lines in Github" })
        '';
      }

      {
        plugin = dracula-nvim;
        type = "lua";
        config = ''
          vim.cmd.colorscheme("dracula")
        '';
      }
      {
        plugin = barbar-nvim;
        type = "lua";
        config = ''
          require("barbar").setup({
            ["animation"] = false,
            auto_hide = 0,
            exclude_ft = {'dump'},
          })
          vim.keymap.set("n", "<C-n>", "<Cmd>BufferNext<CR>", { desc = "Go to next buffer" } )
          vim.keymap.set("n", "<C-p>", "<Cmd>BufferPrevious<CR>", { desc = "Go to previous buffer" } )
          vim.keymap.set("n", "<C-q>", "<Cmd>BufferClose<CR>", { desc = "Close current buffer" } )
        '';
      }
      {
        plugin = winresize-nvim;
        type = "lua";
        config = ''
          vim.keymap.set("n", "<C-h>", function() require("winresize").resize(0, 2, "left") end)
          vim.keymap.set("n", "<C-j>", function() require("winresize").resize(0, 1, "down") end)
          vim.keymap.set("n", "<C-k>", function() require("winresize").resize(0, 1, "up") end)
          vim.keymap.set("n", "<C-l>", function() require("winresize").resize(0, 2, "right") end)
        '';
      }
      {
        plugin = nvim-surround;
        type = "lua";
        config = ''
          require("nvim-surround").setup({})
        '';
      }
      {
        plugin = hop-nvim;
        type = "lua";
        config = ''
          require("hop").setup { keys = 'etovxqpdygfblzhckisuran' }
          vim.keymap.set("n", "<leader><leader>", require('hop').hint_words, { desc = "Hop cursor to hint words" })
          vim.keymap.set("v", "<leader><leader>", function() require('hop').hint_words({ hint_position = require('hop.hint').HintPosition.END }) end, { desc = "Hop cursor to hint words" })
        '';
      }
      {
        plugin = blame-nvim;
        type = "lua";
        config = ''
          require("blame").setup()
          vim.keymap.set("n", "<leader>gb", "<Cmd>BlameToggle<CR>")
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "blame",
            callback = function()
              vim.bo.buflisted = false
              vim.keymap.set("n", "<C-q>", ":clo<CR>", { buffer = true, desc = "Close blame window" })
              vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
            end,
          })
        '';
      }
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''
          require("gitsigns").setup()
        '';
      }
      {plugin = blink-cmp-copilot;}
      {
        plugin = blink-cmp;
        type = "lua";
        config = ''
          require("blink.cmp").setup({
            keymap = { preset = 'enter' },
            signature = {
              enabled = true,
              window = { border = "single" },
            },
            completion = {
              list = { selection = { preselect = false, auto_insert = false } },
              documentation = { window = { border = "single" } },
              menu = { border = "single" },
            },
            sources = {
              default = { "lsp", "path", "snippets", "buffer", "copilot" },
              providers = {
                copilot = {
                  name = "copilot",
                  module = "blink-cmp-copilot",
                  score_offset = 100,
                  async = true,
                },
              },
            },
          })
        '';
      }
      {
        plugin = fidget-nvim;
        type = "lua";
        config = ''
          require("fidget").setup({})
        '';
      }
      {
        plugin = nvim-navic;
        type = "lua";
        config = ''
          require('nvim-navic').setup {
            lsp = { auto_attach = true },
          }
        '';
      }
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          local navic = require("nvim-navic")
          require("lualine").setup({
              sections = {
                  lualine_c = {
                      { "navic" }
                  }
              },
          })
        '';
      }

      {
        plugin = lsp_lines-nvim;
        type = "lua";
        config = ''
          vim.diagnostic.config({ virtual_text = false })
          require("lsp_lines").setup()
          vim.keymap.set("n", "<Leader>ll", require("lsp_lines").toggle, { desc = "Toggle lsp_lines" })
        '';
      }
    ];
  };
}

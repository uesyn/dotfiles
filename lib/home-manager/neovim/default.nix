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
  cellwidths-nvim = mkNvimPlugin "cellwidths.nvim" "https://github.com/delphinus/cellwidths.nvim.git" "main" "98d8b428020c7e0af098f316a02490e5b37e98da";
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
    package = pkgs.unstable.neovim-unwrapped;

    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      bash
      fzf
      ripgrep
      unstable.copilot-language-server
    ];

    extraLuaConfig = ''
      vim.loader.enable()

      -- Set up globals
      vim.g["loaded_perl_provider"] = 0
      vim.g["loaded_python_provider"] = 0
      vim.g["loaded_ruby_provider"] = 0
      vim.g["mapleader"] = " "
      vim.g["netrw_fastbrowse"] = 0

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

      -- autocmds
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "qf",
        callback = function()
          vim.bo.buflisted = false
          vim.keymap.set("n", "<C-q>", "<Cmd>clo<CR>", { buffer = true })
          vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
          vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
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
            vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
          end

          local bufnr = args.buf
          local bufopts = { noremap = true, silent = true, buffer = bufnr }
          vim.keymap.set("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", bufopts)
          vim.keymap.set("n", "gD", "<Cmd>lua require('fzf-lua').lsp_declarations()<CR>", bufopts)
          vim.keymap.set("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", bufopts)
          vim.keymap.set("n", "gr", "<Cmd>lua require('fzf-lua').lsp_references()<CR>", bufopts)
          vim.keymap.set("n", "gi", "<Cmd>lua require('fzf-lua').lsp_implementations()<CR>", bufopts)
          vim.keymap.set("n", "gt", "<Cmd>lua require('fzf-lua').lsp_typedefs()<CR>", bufopts)
          vim.keymap.set("n", "gI", "<Cmd>lua require('fzf-lua').lsp_incoming_calls()<CR>", bufopts)
          vim.keymap.set("n", "gO", "<Cmd>lua require('fzf-lua').lsp_outgoing_calls()<CR>", bufopts)
          vim.keymap.set("n", "gs", "<Cmd>lua require('fzf-lua').lsp_document_symbols()<CR>", bufopts)
          vim.keymap.set("n", "<leader>lR", "<Cmd>lua vim.lsp.buf.rename()<CR>", bufopts)
          vim.keymap.set("n", "<leader>la", "<Cmd>lua require('fzf-lua').lsp_code_actions()<CR>", bufopts)
          vim.keymap.set("n", "<leader>ld", "<Cmd>lua require('fzf-lua').lsp_document_diagnostics()<CR>", bufopts)
          vim.keymap.set("n", "<leader>lf", function()
              vim.lsp.buf.format({ async = true })
          end, bufopts)
          vim.keymap.set(
            "n",
            "<leader>li",
            "<Cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>",
            bufopts
          )
        end,
      })
      vim.lsp.enable({'gopls', 'typescript-language-server', 'rust_analyzer'})
    '';

    plugins = with pkgs.unstable.vimPlugins; [
      lz-n
      nvim-web-devicons
      plenary-nvim
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
          vim.keymap.set("n", "<C-n>", "<Cmd>BufferNext<CR>")
          vim.keymap.set("n", "<C-p>", "<Cmd>BufferPrevious<CR>")
          vim.keymap.set("n", "<C-q>", "<Cmd>BufferClose<CR>")
        '';
      }
      {
        plugin = cellwidths-nvim;
        type = "lua";
        config = ''
          require("cellwidths").setup { name = "default" }
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
        plugin = fzf-lua;
        type = "lua";
        config = ''
          vim.keymap.set("n", "<Leader>fs", require('fzf-lua').live_grep)
          vim.keymap.set("n", "<Leader>ff", require('fzf-lua').files)
          vim.keymap.set("n", "<Leader>;", require('fzf-lua').resume)
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
        plugin = openingh-nvim;
        type = "lua";
        config = ''
          vim.keymap.set("n", "<Leader>ho", "<Cmd>OpenInGHFile<CR>")
          vim.keymap.set("v", "<Leader>ho", "<Esc><Cmd>'<,'>OpenInGHFile<CR>")
        '';
        optional = true;
      }
      {
        plugin = nvim-osc52;
        type = "lua";
        config = ''
          vim.keymap.set("v", "<leader>y", require("osc52").copy_visual)
          vim.api.nvim_create_autocmd("TextYankPost", {
            pattern = "*",
            callback = function()
              if vim.v.event.operator == "y" then
                  require("osc52").copy_register("")
              end
            end,
          })
        '';
      }
      {
        plugin = hop-nvim;
        type = "lua";
        config = ''
          require("hop").setup { keys = 'etovxqpdygfblzhckisuran' }
          vim.keymap.set("n", "<leader><leader>", require('hop').hint_words)
          vim.keymap.set("v", "<leader><leader>", function() require('hop').hint_words({ hint_position = require('hop.hint').HintPosition.END }) end)
        '';
      }
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
          vim.g.loaded_netrw = 1
          vim.g.loaded_netrwPlugin = 1

          local function my_on_attach(bufnr)
            local api = require("nvim-tree.api")

            local function opts(desc)
              return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
            end

            local function has_marked_nodes()
              local marked_list = api.marks.list()
              return next(marked_list) ~= nil
            end

            local function custom_delete(node)
              if has_marked_nodes() then
                api.marks.bulk.delete()
              else
                api.fs.remove(node)
              end
            end

            -- custom mappings
            vim.keymap.set("n", "h",              api.node.navigate.parent_close,     opts("Close Directory"))
            vim.keymap.set("n", "<CR>",           api.node.open.edit,                 opts("Open"))
            vim.keymap.set("n", "l",              api.node.open.edit,                 opts("Open"))
            vim.keymap.set("n", "<Tab>",          api.node.open.preview,              opts("Open Preview"))
            vim.keymap.set("n", "a",              api.fs.create,                      opts("Create File Or Directory"))
            vim.keymap.set("n", "c",              api.fs.copy.node,                   opts("Copy"))
            vim.keymap.set("n", "D",              custom_delete,                      opts("Delete"))
            vim.keymap.set("n", "?",              api.tree.toggle_help,               opts("Help"))
            vim.keymap.set("n", "o",              api.node.open.edit,                 opts("Open"))
            vim.keymap.set("n", "p",              api.fs.paste,                       opts("Paste"))
            vim.keymap.set("n", "q",              api.tree.close,                     opts("Close"))
            vim.keymap.set("n", "<C-q>",          api.tree.close,                     opts("Close"))
            vim.keymap.set("n", "r",              api.fs.rename,                      opts("Rename"))
            vim.keymap.set("n", "x",              api.fs.cut,                         opts("Cut"))
            vim.keymap.set("n", ";",              api.marks.toggle,                   opts("Mark"))
            vim.keymap.set("n", ":",              api.marks.clear,                    opts("Clera Marks"))
            vim.keymap.set("n", "M",              api.marks.bulk.move,                opts("Move Marked Nodes"))
            vim.keymap.set("n", "y",              api.fs.copy.filename,               opts("Copy Name"))
            vim.keymap.set("n", "Y",              api.fs.copy.absolute_path,          opts("Copy Absolute Path"))
            vim.keymap.set("n", "<C-n>", "<Nop>", opts(""))
            vim.keymap.set("n", "<C-p>", "<Nop>", opts(""))
          end

          require("nvim-tree").setup({
            on_attach = my_on_attach,
            view = {
              float = {
                enable = true,
              },
            },
            actions = {
              open_file = {
                resize_window = false,
              },
            },
            reload_on_bufenter = true,
            renderer = {
              full_name = true,
              icons = {
                show = {
                  folder_arrow = false,
                },
                glyphs = {
                  folder = {
                    arrow_closed = "",
                    arrow_open = "",
                  },
                },
              },
            },
          })
          vim.keymap.set("n", "<Leader>fo", "<Cmd>NvimTreeToggle<CR>", { silent = true })
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
              vim.keymap.set("n", "<C-q>", ":clo<CR>", { buffer = true })
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
      {
        plugin = copilot-lua;
        type = "lua";
        config = ''
          require("copilot").setup({
            -- fix path
            lsp_binary = "copilot-language-server",
            suggestion = { enabled = false },
            panel = { enabled = false },
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
        plugin = dressing-nvim;
      }
      {
        plugin = nui-nvim;
      }
      {
        plugin = tiny-inline-diagnostic-nvim;
        type = "lua";
        config = ''
          require('tiny-inline-diagnostic').setup()
          vim.diagnostic.config({ virtual_text = false })
        '';
      }
    ];

    extraLuaPackages = ps: [
      ps.tiktoken_core # depended by CopilotChat-nvim
    ];
  };
}

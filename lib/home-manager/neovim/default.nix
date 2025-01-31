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
      bash-language-server
      fzf
      # jdt-language-server
      nil # nix LSP
      nodePackages.typescript-language-server
      pyright
      ripgrep
      unstable.gopls
      unstable.rust-analyzer
    ];

    extraLuaConfig = ''
      vim.loader.enable()

      -- Set up globals
      vim.g["loaded_perl_provider"] = 0
      vim.g["loaded_python_provider"] = 0
      vim.g["loaded_ruby_provider"] = 0
      vim.g["mapleader"] = " "
      vim.g["netrw_fastbrowse"] = 0
      vim.g["vim_markdown_conceal"] = 0
      vim.g["vim_markdown_no_default_key_mappings"] = 1

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

      -- keymaps
      vim.keymap.set({"n", "v"}, "<leader>", "<Nop>")
      vim.keymap.set("n", "ZZ", "<Nop>")
      vim.keymap.set("n", "ZQ", "<Nop>")
      vim.keymap.set("n", "q", "<Nop>")
      vim.keymap.set("n", "Q", "<Nop>")
      vim.keymap.set("n", "<S-l>", "<C-w>l")
      vim.keymap.set("n", "<S-h>", "<C-w>h")
      vim.keymap.set("n", "<S-k>", "<C-w>k")
      vim.keymap.set("n", "<S-j>", "<C-w>j")

      -- autocmds
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("my_quickfix", { clear = true }),
        pattern = "qf",
        callback = function()
          vim.bo.buflisted = false
          vim.keymap.set("n", "<C-q>", "<Cmd>clo<CR>", { buffer = true })
          vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
          vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
        end,
      })
    '';

    plugins = with pkgs.unstable.vimPlugins; [
      lz-n
      nvim-web-devicons
      plenary-nvim
      {
        plugin = dracula-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "dracula.nvim",
            colorscheme = "dracula",
          }
          vim.cmd.colorscheme("dracula")
        '';
        optional = true;
      }
      {
        plugin = barbar-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "barbar.nvim",
            event = "DeferredUIEnter",
            after = function()
              require("barbar").setup({
                ["animation"] = false,
                auto_hide = 0,
                exclude_ft = {'dump'},
              })
              vim.keymap.set("n", "<C-n>", "<Cmd>BufferNext<CR>")
              vim.keymap.set("n", "<C-p>", "<Cmd>BufferPrevious<CR>")
              vim.keymap.set("n", "<C-q>", "<Cmd>BufferClose<CR>")
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = cellwidths-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "cellwidths.nvim",
            event = "DeferredUIEnter",
            after = function()
              require("cellwidths").setup { name = "default" }
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = winresize-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "winresize.nvim",
            keys = { "<C-h>", "<C-j>", "<C-k>", "<C-l>" },
            after = function()
              vim.keymap.set("n", "<C-h>", function() require("winresize").resize(0, 2, "left") end)
              vim.keymap.set("n", "<C-j>", function() require("winresize").resize(0, 1, "down") end)
              vim.keymap.set("n", "<C-k>", function() require("winresize").resize(0, 1, "up") end)
              vim.keymap.set("n", "<C-l>", function() require("winresize").resize(0, 2, "right") end)
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = fzf-lua;
        type = "lua";
        config = ''
          require("lz.n").load {
            "fzf-lua",
            keys = { "<Leader>fs", "<Leader>ff", "<Leader>fb" },
            after = function()
              vim.keymap.set("n", "<Leader>fs", require('fzf-lua').live_grep)
              vim.keymap.set("n", "<Leader>ff", require('fzf-lua').files)
              vim.keymap.set("n", "<Leader>;", require('fzf-lua').resume)
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = nvim-surround;
        type = "lua";
        config = ''
          require("lz.n").load {
            "nvim-surround",
            event = "DeferredUIEnter",
            after = function()
              require("nvim-surround").setup({})
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = openingh-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "openingh.nvim",
            keys = {
              { "<Leader>ho", mode = "n" },
              { "<Leader>ho", mode = "v" }
            },
            after = function()
              vim.keymap.set("n", "<Leader>ho", "<Cmd>OpenInGHFile<CR>")
              vim.keymap.set("v", "<Leader>ho", "<Esc><Cmd>'<,'>OpenInGHFile<CR>")
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = nvim-osc52;
        type = "lua";
        config = ''
          require("lz.n").load {
            "nvim-osc52",
            event = "DeferredUIEnter",
            after = function()
              vim.keymap.set("v", "<leader>y", require("osc52").copy_visual)
              vim.api.nvim_create_autocmd("TextYankPost", {
                group = vim.api.nvim_create_augroup("my_nvim_osc52", { clear = true }),
                pattern = "*",
                callback = function()
                  if vim.v.event.operator == "y" then
                      require("osc52").copy_register("")
                  end
                end,
              })
            end,
          }
        '';
      }
      {
        plugin = hop-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "hop.nvim",
            keys = { "<Leader><Leader>" },
            after = function()
              require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
              vim.keymap.set("n", "<leader><leader>", require('hop').hint_words)
              vim.keymap.set("v", "<leader><leader>", function() require('hop').hint_words({ hint_position = require('hop.hint').HintPosition.END }) end)
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
          require("lz.n").load {
            "nvim-tree.lua",
            keys = "<Leader>fo",
            after = function()
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
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = blame-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "blame.nvim",
            keys = { "<Leader>gb" },
            after = function()
              require("blame").setup()
              vim.keymap.set("n", "<leader>gb", "<Cmd>BlameToggle<CR>")
              vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("my_blame", { clear = true }),
                pattern = "blame",
                callback = function()
                  vim.bo.buflisted = false
                  vim.keymap.set("n", "<C-q>", ":clo<CR>", { buffer = true })
                  vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
                  vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
                end,
              })
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "gitsigns.nvim",
            event = "DeferredUIEnter",
            after = function()
              require("gitsigns").setup()
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = copilot-lua;
        type = "lua";
        config = ''
          require("lz.n").load {
            "copilot.lua",
            after = function()
              require("copilot").setup({
                suggestion = { enabled = false },
                panel = { enabled = false },
              })
            end,
          }
        '';
      }
      {
        plugin = CopilotChat-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "CopilotChat.nvim",
            keys = {
              { "<Leader>cC", mode = "n" },
              { "<Leader>cd", mode = "v" },
              { "<Leader>ce", mode = "v" },
              { "<Leader>cr", mode = "v" },
              { "<Leader>ct", mode = "v" },
              { "<Leader>cc", mode = "n" },
              { "<Leader>cj", mode = "v" },
            },
            after = function()
              require("CopilotChat").setup({
                prompts = {
                  Explain = {
                    prompt = '/COPILOT_EXPLAIN Write an explanation for the active selection as paragraphs of text in Japanese.',
                  },
                  Review = {
                    prompt = '/COPILOT_REVIEW Review the selected code in Japanese.',
                  },
                },
              })
              vim.keymap.set("n", "<Leader>cC", '<Cmd>lua require("CopilotChat").open()<CR>')
              vim.keymap.set("v", "<Leader>cd", '<Cmd>CopilotChatDocs<CR>')
              vim.keymap.set("v", "<Leader>ce", '<Cmd>CopilotChatExplain<CR>')
              vim.keymap.set("v", "<Leader>cr", '<Cmd>CopilotChatReview<CR>')
              vim.keymap.set("v", "<Leader>ct", '<Cmd>CopilotChatTests<CR>')
              vim.keymap.set("n", "<Leader>cc", '<Cmd>CopilotChatCommit<CR>')
              vim.keymap.set("v", "<Leader>cj", '<Cmd>lua require("CopilotChat").ask("Translate to Japanese.", { selection = require("CopilotChat.select").visual })<CR>')

              vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("my_copilotchat", { clear = true }),
                pattern = "copilot-chat",
                callback = function()
                  vim.keymap.set("n", "<C-q>", '<Cmd>lua require("CopilotChat").toggle()<CR>', { buffer = true })
                end,
              })
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = blink-cmp-copilot;
        type = "lua";
        config = ''
          require("lz.n").load {
            "blink-cmp-copilot",
          }
        '';
      }
      {
        plugin = blink-cmp;
        type = "lua";
        config = ''
          require("lz.n").load {
            "blink.cmp",
            event = "DeferredUIEnter",
            after = function()
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
                      name = "Copilot",
                      module = "blink-cmp-copilot",
                      score_offset = 100,
                      async = true,
                    },
                  },
                },
              })
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = fidget-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "fidget.nvim",
            event = "LspAttach",
            after = function()
              require("fidget").setup({})
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = nvim-navic;
        type = "lua";
        config = ''
          require("lz.n").load {
            "nvim-navic",
            after = function()
              require('nvim-navic').setup {
                lsp = { auto_attach = true },
              }
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "lualine.nvim",
            after = function()
              require('lz.n').trigger_load("nvim-navic")
              local navic = require("nvim-navic")

              require("lualine").setup({
                  sections = {
                      lualine_c = {
                          { "navic" }
                      }
                  },
              })
            end,
          }
        '';
      }
      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = ''
          require("lz.n").load {
            "nvim-lspconfig",
            after = function()
              require('lz.n').trigger_load("fzf-lua")
              require('lz.n').trigger_load("blink.cmp")
              vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("my_lspconfig", { clear = true }),
                callback = function(args)
                  if not (args.data and args.data.client_id) then
                    return
                  end

                  local bufnr = args.buf
                  local client = vim.lsp.get_client_by_id(args.data.client_id)

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

              function make_client_capabilities()
                local capabilities = vim.lsp.protocol.make_client_capabilities()
                capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)
                return capabilities
              end

              local lspconfig = require("lspconfig")

              if vim.fn.executable("gopls") == 1 then
                lspconfig.gopls.setup({
                  capabilities = make_client_capabilities(),
                  settings = {
                    gopls = {
                      hints = {
                        assignVariableTypes = false,
                        compositeLiteralFields = false,
                        compositeLiteralTypes = false,
                        constantValues = false,
                        functionTypeParameters = false,
                        parameterNames = false,
                        rangeVariableTypes = false,
                      },
                    },
                  },
                })
              end

              if vim.fn.executable("typescript-language-server") == 1 then
                lspconfig.ts_ls.setup({
                  capabilities = make_client_capabilities(),
                  root_dir = require("lspconfig").util.root_pattern("package.json"),
                })
              end

              if vim.fn.executable("deno") == 1 then
                lspconfig.denols.setup({
                  capabilities = make_client_capabilities(),
                  root_dir = require("lspconfig").util.root_pattern("deno.json", "deno.jsonc", "deps.ts", "import_map.json"),
                  settings = {
                    denols = {
                      enable = true,
                      lint = true,
                      unstable = true,
                      suggest = {
                        imports = {
                          autoDiscovery = true,
                        },
                      },
                    },
                  },
                })
              end

              if vim.fn.executable("rust-analyzer") == 1 then
                lspconfig.rust_analyzer.setup({
                  -- Server-specific settings. See `:help lspconfig-setup`
                  capabilities = make_client_capabilities(),
                  settings = {
                    ["rust-analyzer"] = {
                      cargo = { allFeatures = true },
                      checkOnSave = { allFeatures = true },
                      diagnostics = {
                        enable = true,
                        disabled = { "unresolved-proc-macro" },
                        enableExperimental = true,
                      },
                    },
                  },
                })
              end

              if vim.fn.executable("bash-language-server") == 1 then
                lspconfig.bashls.setup({
                  capabilities = make_client_capabilities(),
                })
              end

              if vim.fn.executable("pyright") == 1 then
                lspconfig.pyright.setup({
                  capabilities = make_client_capabilities(),
                })
              end

              -- nix language server
              if vim.fn.executable("nil") == 1 then
                lspconfig.nil_ls.setup({
                  capabilities = make_client_capabilities(),
                })
              end

              if vim.fn.executable("jdtls") == 1 then
                lspconfig.jdtls.setup({
                  capabilities = make_client_capabilities(),
                })
              end
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = dressing-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "dressing.nvim",
          }
        '';
        optional = true;
      }
      {
        plugin = nui-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "nui.nvim",
          }
        '';
        optional = true;
      }
      {
        plugin = render-markdown-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "render-markdown.nvim",
            ft = { "markdown", "Avante" },
            after = function()
              require('render-markdown').setup({
                file_types = { "markdown", "Avante" },
              })
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = avante-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "avante.nvim",
            event = "DeferredUIEnter",
            enabled = function()
              local path = vim.fn.expand("~/.config/github-copilot/apps.json")
              return vim.fn.filereadable(path) == 1
            end,
            after = function()
              require('avante_lib').load()
              require('avante').setup({
                provider = "copilot",
              })

              vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("my_avante", { clear = true }),
                pattern = "Avante*",
                callback = function()
                  vim.keymap.set({"n", "i", "v"}, "<C-q>", "<Cmd>AvanteToggle<CR>", { buffer = true })
                end,
              })
            end,
          }
        '';
        optional = true;
      }
      {
        plugin = tiny-inline-diagnostic-nvim;
        type = "lua";
        config = ''
          require("lz.n").load {
            "tiny-inline-diagnostic.nvim",
            event = "DeferredUIEnter",
            after = function()
              require('tiny-inline-diagnostic').setup()
              vim.diagnostic.config({ virtual_text = false })
            end,
          }
        '';
        optional = true;
      }
    ];

    extraLuaPackages = ps: [
      ps.tiktoken_core # depended by CopilotChat-nvim
    ];
  };
}

local lsp = vim.api.nvim_create_augroup("LSP", { clear = true })

return {
  {
    'SmiteshP/nvim-navic',
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp,
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client.server_capabilities.documentSymbolProvider then
            require("nvim-navic").attach(client, bufnr)
          end
        end,
      })
    end
  },

  {
    'mrded/nvim-lsp-notify',
    requires = { 'nvim-notify' },
    config = function()
      require('lsp-notify').setup({
        notify = require('notify'),
      })
    end
  },

  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'hrsh7th/cmp-buffer',
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-vsnip',
      'hrsh7th/vim-vsnip',
    },
    config = function()
      -- vim.lsp.set_log_level("debug") -- for debug
      vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp,
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local bufnr = args.buf
          -- local client = vim.lsp.get_client_by_id(args.data.client_id)
          vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

          local bufopts = { noremap = true, silent = true, buffer = bufnr }
          vim.keymap.set('n', '<space>lD', vim.lsp.buf.declaration, bufopts)
          vim.keymap.set('n', '<space>ld', vim.lsp.buf.definition, bufopts)
          vim.keymap.set('n', '<space>lh', vim.lsp.buf.hover, bufopts)
          vim.keymap.set('n', '<space>lt', vim.lsp.buf.type_definition, bufopts)
          vim.keymap.set('n', '<space>lr', vim.lsp.buf.references, bufopts)
          vim.keymap.set('n', '<space>lR', vim.lsp.buf.rename, bufopts)
          vim.keymap.set('n', '<space>la', vim.lsp.buf.code_action, bufopts)
          vim.keymap.set('n', '<space>lf', function() vim.lsp.buf.format { async = true } end, bufopts)
          vim.keymap.set('n', '<space>lI', vim.lsp.buf.implementation, bufopts)
        end,
      })

      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-x><C-o>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = false }),
          ['<Tab>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
        }),
        experimental = {
          ghost_text = true,
        }
      })

      local lspconfig = require('lspconfig')
      local handlers = {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' }),
        ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'rounded' }),
      }
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      lspconfig.gopls.setup {
        handlers = handlers,
        capabilities = capabilities,
        settings = {
          gopls = {
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
          },
        },
      }
      lspconfig.tsserver.setup {
        handlers = handlers,
        capabilities = capabilities,
        root_dir = require('lspconfig').util.root_pattern("package.json"),
      }
      lspconfig.denols.setup {
        handlers = handlers,
        capabilities = capabilities,
        root_dir = require('lspconfig').util.root_pattern("deno.json", "deno.jsonc", "deps.ts",
          "import_map.json"),
        settings = {
          denols = {
            enable = true,
            lint = true,
            unstable = true,
            suggest = {
              imports = {
                autoDiscovery = true,
              }
            },
          },
        },
      }
      lspconfig.rust_analyzer.setup {
        -- Server-specific settings. See `:help lspconfig-setup`
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
      }
    end
  },

  {
    "github/copilot.vim",
    init = function()
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      local keymap = vim.keymap.set
      -- https://github.com/orgs/community/discussions/29817#discussioncomment-4217615
      keymap(
        "i",
        "<C-l>",
        'copilot#Accept("<CR>")',
        { silent = true, expr = true, script = true, replace_keycodes = false }
      )
      keymap("i", "<C-j>", "<Plug>(copilot-next)")
      keymap("i", "<C-k>", "<Plug>(copilot-previous)")
      keymap("i", "<C-o>", "<Plug>(copilot-dismiss)")
      keymap("i", "<C-f>", "<Plug>(copilot-suggest)")
    end,
  },
}

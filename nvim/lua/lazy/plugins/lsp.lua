return {
  {
    'lvimuser/lsp-inlayhints.nvim',
    config = function()
      require("lsp-inlayhints").setup()
      vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
      vim.api.nvim_create_autocmd("LspAttach", {
        group = "LspAttach_inlayhints",
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client.server_capabilities.inlayHintProvider then
            require("lsp-inlayhints").on_attach(client, bufnr, true)
          end
        end,
      })
    end
  },

  {
    'SmiteshP/nvim-navic',
    config = function()
      vim.api.nvim_create_augroup("LspAttach_nvim_navic", {})
      vim.api.nvim_create_autocmd("LspAttach", {
        group = "LspAttach_nvim_navic",
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
    'nvim-lua/lsp-status.nvim',
    config = function()
      local lsp_status = require('lsp-status')
      lsp_status.register_progress()
      vim.api.nvim_create_augroup("LspAttach_lsp_status", {})
      vim.api.nvim_create_autocmd("LspAttach", {
        group = "LspAttach_lsp_status",
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local client = vim.lsp.get_client_by_id(args.data.client_id)
          lsp_status.on_attach(client)
        end,
      })
    end
  },

  {
    'neovim/nvim-lspconfig',
    event = "VeryLazy",
    dependencies = {
      'hrsh7th/cmp-buffer',
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      -- vim.lsp.set_log_level("debug") -- for debug

      local cmp = require("cmp")
      cmp.setup({
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs( -4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          -- ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
        }, {
          { name = 'buffer' },
        })
      })

      local on_attach = function(client, bufnr)
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
      end

      local handlers = {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' }),
        ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'rounded' }),
      }

      -- local capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      local settings = {
        Lua = {
          runtime = {
            version = 'LuaJIT',
          },
          diagnostics = {
            globals = { 'vim' },
          },
          telemetry = {
            enable = false,
          },
          hint = {
            enable = true,
          },
        },
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
      }

      local function setup_handler(server_name)
        require("lspconfig")[server_name].setup {
          on_attach = on_attach,
          handlers = handlers,
          capabilities = capabilities,
          settings = settings,
        }
      end

      require("mason").setup(
        {
          ui = {
            border = "rounded"
          }
        }
      )
      require("mason-lspconfig").setup()
      require("mason-lspconfig").setup_handlers({ setup_handler })
    end
  }
}

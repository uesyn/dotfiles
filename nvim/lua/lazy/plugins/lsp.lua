return {
  {
    'neovim/nvim-lspconfig',
    event = 'VeryLazy',
    dependencies = {
      'hrsh7th/cmp-buffer',
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'nvim-lua/lsp-status.nvim',
      'SmiteshP/nvim-navic',
      'folke/neodev.nvim',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'lvimuser/lsp-inlayhints.nvim'
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

      require("neodev").setup()

      require("lsp-inlayhints").setup()

      local lsp_status = require('lsp-status')
      lsp_status.register_progress()

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
        if client.server_capabilities.documentSymbolProvider then
          require("nvim-navic").attach(client, bufnr)
        end
        lsp_status.on_attach(client)

        if client.server_capabilities.inlayHintProvider then
          require("lsp-inlayhints").on_attach(client, bufnr, true)
        end
      end

      local handlers = {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' }),
        ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'rounded' }),
      }

      -- local capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      capabilities = vim.tbl_extend('keep', capabilities, lsp_status.capabilities)

      local settings = {
        Lua = {
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

return {
  {
    'neovim/nvim-lspconfig',
    event = 'BufReadPre',
    dependencies = {
      'hrsh7th/cmp-buffer',
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'nvim-lua/lsp-status.nvim',
      'SmiteshP/nvim-navic',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'simrat39/inlay-hints.nvim',
    },
    enabled = vim.g.use_nvim_lsp,
    config = function()
      local cmp = require 'cmp'
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

      -- vim.lsp.set_log_level("debug") -- for debug
      local inlay_hints = require("inlay-hints")
      inlay_hints.setup()

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
          inlay_hints.on_attach(client, bufnr)
        end
      end

      -- local capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      capabilities = vim.tbl_extend('keep', capabilities, lsp_status.capabilities)

      local function setup_handler(server_name)
        require("lspconfig")[server_name].setup {
          on_attach = on_attach,
          capabilities = capabilities,
        }
      end

      require("mason").setup()
      require("mason-lspconfig").setup()
      require("mason-lspconfig").setup_handlers({ setup_handler })

      -- Use language server directly.
      local servers = { "gopls", "rust_analyzer" }
      for _, server in ipairs(servers) do
        require("lspconfig")[server].setup {
          on_attach = on_attach,
          capabilities = capabilities,
        }
      end
    end
  }
}

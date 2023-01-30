return {
  'neovim/nvim-lspconfig',
  version = '*',
  event = "BufReadPre",
  dependencies = {
    { 'echasnovski/mini.completion', version = '*' },
    'nvim-lua/lsp-status.nvim',
    'SmiteshP/nvim-navic'
  },
  enabled = vim.g.use_nvim_lsp,
  config = function()
    -- vim.lsp.set_log_level("debug") -- for debug
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
      vim.keymap.set('n', '<space>lwa', vim.lsp.buf.add_workspace_folder, bufopts)
      vim.keymap.set('n', '<space>lwr', vim.lsp.buf.remove_workspace_folder, bufopts)
      vim.keymap.set('n', '<space>lwl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, bufopts)
      vim.keymap.set('n', '<space>lI', vim.lsp.buf.implementation, bufopts)
      if client.server_capabilities.documentSymbolProvider then
        require("nvim-navic").attach(client, bufnr)
      end
      lsp_status.on_attach(client)
    end

    local capabilities = vim.tbl_extend('keep', vim.lsp.protocol.make_client_capabilities(), lsp_status.capabilities)

    local lspconfig = require('lspconfig')
    lspconfig.rust_analyzer.setup {
      on_attach = on_attach,
      capabilities = capabilities,
      single_file_support = false,
    }
    lspconfig.gopls.setup {
      on_attach = on_attach,
      capabilities = capabilities,
      single_file_support = false,
    }

    require('mini.completion').setup {
      window = {
        info = { height = 25, width = 80, border = 'single' },
        signature = { height = 25, width = 80, border = 'single' },
      },
    }
  end
}

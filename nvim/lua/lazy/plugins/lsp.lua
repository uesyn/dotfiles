return {
  {
    'neovim/nvim-lspconfig',
    version = '*',
    event = 'BufReadPre',
    dependencies = {
      { 'echasnovski/mini.completion', version = '*' },
      'nvim-lua/lsp-status.nvim',
      'SmiteshP/nvim-navic',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'simrat39/inlay-hints.nvim',
    },
    enabled = vim.g.use_nvim_lsp,
    config = function()
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

      local capabilities = vim.tbl_extend('keep', vim.lsp.protocol.make_client_capabilities(), lsp_status.capabilities)

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

      require('mini.completion').setup {
        window = {
          info = { height = 25, width = 80, border = 'single' },
          signature = { height = 25, width = 80, border = 'single' },
        },
      }
    end
  },

  {
    'prabirshrestha/vim-lsp',
    dependencies = {
      'prabirshrestha/asyncomplete.vim',
      'prabirshrestha/asyncomplete-lsp.vim',
      'mattn/vim-lsp-settings',
    },
    enabled = not vim.g.use_nvim_lsp,
    init = function()
      vim.g.lsp_work_done_progress_enabled = 1
      vim.g.lsp_document_code_action_signs_enabled = 0
      vim.g.lsp_diagnostics_echo_cursor = 0
      vim.g.lsp_diagnostics_echo_delay = 50
      vim.g.lsp_diagnostics_highlights_enabled = 0
      vim.g.lsp_diagnostics_highlights_delay = 50
      vim.g.lsp_diagnostics_highlights_insert_mode_enabled = 0
      vim.g.lsp_diagnostics_signs_enabled = 1
      vim.g.lsp_diagnostics_signs_delay = 50
      vim.g.lsp_diagnostics_signs_insert_mode_enabled = 0
      vim.g.lsp_diagnostics_virtual_text_enabled = 1
      vim.g.lsp_diagnostics_virtual_text_delay = 50
      vim.g.lsp_diagnostics_float_cursor = 0
      vim.g.lsp_diagnostics_float_delay = 1000
      vim.g.lsp_completion_documentation_delay = 40
      vim.g.lsp_document_highlight_delay = 50
      vim.g.lsp_document_code_action_signs_delay = 100
      vim.g.lsp_fold_enabled = 0
      vim.g.lsp_text_edit_enabled = 0
      vim.g.lsp_settings_filetype_typescript = { 'typescript-language-server', 'deno' }
      vim.g.lsp_settings_filetype_javascript = { 'typescript-language-server', 'deno' }
    end,
    config = function()
      vim.keymap.set('n', '[LSP]D', "<plug>(lsp-declaration)")
      vim.keymap.set('n', '[LSP]d', "<plug>(lsp-definition)")
      vim.keymap.set('n', '[LSP]h', "<plug>(lsp-hover)")
      vim.keymap.set('n', '[LSP]t', "<plug>(lsp-type-definition)")
      vim.keymap.set('n', '[LSP]r', "<plug>(lsp-references)")
      vim.keymap.set('n', '[LSP]R', "<plug>(lsp-rename)")
      vim.keymap.set('n', '[LSP]a', "<plug>(lsp-code-action)")
      vim.keymap.set('n', '[LSP]f', "<plug>(lsp-document-format)")
      vim.keymap.set('n', '[LSP]q', "<plug>(lsp-document-diagnostics)")
      vim.keymap.set('n', '[LSP]i', "<Cmd>LspCodeActionSync source.organizeImports<CR>")
      vim.opt.signcolumn = "yes"
      vim.opt.omnifunc = "lsp#complete"
    end,
  }
}

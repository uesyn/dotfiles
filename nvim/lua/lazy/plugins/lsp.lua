local lsp = vim.api.nvim_create_augroup("LSP", { clear = true })

return {
  {
    'lvimuser/lsp-inlayhints.nvim',
    config = function()
      local inlayhints = require("lsp-inlayhints")
      inlayhints.setup({ enabled_at_startup = false })
      vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp,
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client.server_capabilities.inlayHintProvider then
            inlayhints.on_attach(client, bufnr, true)
            vim.keymap.set('n', '<space>lH', inlayhints.toggle, { noremap = true, silent = true, buffer = bufnr })
          end
        end,
      })
    end
  },

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
    'j-hui/fidget.nvim',
    config = function()
      require("fidget").setup({ window = { blend = 0 } })
      vim.cmd([[highlight! FidgetTask ctermfg=0 guifg=0]])
    end
  },

  {
    'neovim/nvim-lspconfig',
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      'hrsh7th/cmp-buffer',
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
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

      local handlers = {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' }),
        ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'rounded' }),
      }

      -- local capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      local settings = {
        ["rust-analyzer"] = {
          cargo = { allFeatures = true },
          checkOnSave = { allFeatures = true },
        },
        Lua = {
          runtime = { version = 'LuaJIT' },
          diagnostics = { globals = { 'vim' } },
          telemetry = { enable = false },
          hint = { enable = true },
          completion = { enable = true, showWord = "Disable" },
          workspace = { library = { os.getenv("VIMRUNTIME") } },
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
        require("lspconfig")[server_name].setup({
          handlers = handlers,
          capabilities = capabilities,
          settings = settings,
        })
      end

      require("mason").setup({ ui = { border = "rounded" } })
      require("mason-lspconfig").setup()
      require("mason-lspconfig").setup_handlers({ setup_handler })
    end
  }
}

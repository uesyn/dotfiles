return {
  {
    "nvim-lspconfig",
    after = function()
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
          vim.keymap.set("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", bufopts)
          vim.keymap.set("n", "[d", "<Cmd>lua vim.diagnostic.goto_prev()<CR>", bufopts)
          vim.keymap.set("n", "]d", "<Cmd>lua vim.diagnostic.goto_next()<CR>", bufopts)
          vim.keymap.set("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", bufopts)
          vim.keymap.set("n", "gr", "<Cmd>lua require('fzf-lua').lsp_references()<CR>", bufopts)
          vim.keymap.set("n", "gi", "<Cmd>lua require('fzf-lua').lsp_implementations()<CR>", bufopts)
          vim.keymap.set("n", "gt", "<Cmd>lua require('fzf-lua').lsp_typedefs()<CR>", bufopts)
          -- vim.keymap.set("n", "gr", "<Cmd>lua vim.lsp.buf.references()<CR>", bufopts)
          -- vim.keymap.set("n", "gi", "<Cmd>lua vim.lsp.buf.implementation()<CR>", bufopts)
          -- vim.keymap.set("n", "gt", "<Cmd>lua vim.lsp.buf.type_definition()<CR>", bufopts)
          vim.keymap.set("n", "gI", "<Cmd>lua vim.lsp.buf.incoming_calls()<CR>", bufopts)
          vim.keymap.set("n", "gO", "<Cmd>lua vim.lsp.buf.outgoing_calls()<CR>", bufopts)
          vim.keymap.set("n", "<leader>lR", "<Cmd>lua vim.lsp.buf.rename()<CR>", bufopts)
          vim.keymap.set("n", "<leader>la", "<Cmd>lua vim.lsp.buf.code_action()<CR>", bufopts)
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
        local cmp_lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()
        capabilities = vim.tbl_deep_extend('keep', capabilities, cmp_lsp_capabilities)
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
        lspconfig.tsserver.setup({
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
  },
  { "cmp-nvim-lsp" },
  { "cmp-nvim-lsp-signature-help" },
  { "cmp-snippy" },
  { "nvim-snippy" },
  {
    "nvim-cmp",
    after = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("snippy").expand_snippet(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-x><C-o>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "nvim_lsp_signature_help" },
          { name = "snippy" },
        },
        experimental = {
          ghost_text = true,
        },
      })
    end,
    event = "BufEnter",
  },
  {
    "fidget.nvim",
    after = function()
      require("fidget").setup({})
    end,
    event = "LspAttach",
  },
  {
    "nvim-navic",
    after = function()
      require('nvim-navic').setup {
        highlight = true,
      }

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("my_nvim_navic", { clear = true }),
        callback = function(args)
          if not (args.data and args.data.client_id) then
              return
          end

          vim.opt.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"

          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          require('nvim-navic').attach(client, bufnr)
        end,
      })
    end,
    event = "BufEnter",
  },
}

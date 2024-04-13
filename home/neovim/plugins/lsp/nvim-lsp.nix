{ pkgs, ... }:
{
  programs.nixvim = {
     extraPlugins = with pkgs.vimPlugins; [
       nvim-lspconfig
       cmp-buffer
       nvim-cmp
       cmp-nvim-lsp
       cmp-vsnip
       vim-vsnip
     ];

     extraConfigLua = ''
       local lsp = vim.api.nvim_create_augroup("LSP", { clear = true })
       -- vim.lsp.set_log_level("debug") -- for debug
       vim.api.nvim_create_autocmd("LspAttach", {
         group = lsp,
         callback = function(args)
           if not (args.data and args.data.client_id) then
             return
           end

           local bufnr = args.buf
	   local client = vim.lsp.get_client_by_id(args.data.client_id)
           if client.supports_method("textDocument/inlayHint") or client.server_capabilities.inlayHintProvider then
             vim.lsp.inlay_hint.enable(true)
           end

           vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

           local bufopts = { noremap = true, silent = true, buffer = bufnr }
           vim.keymap.set('n', '[LSP]D', vim.lsp.buf.declaration, bufopts)
           vim.keymap.set('n', '[LSP]d', vim.lsp.buf.definition, bufopts)
           vim.keymap.set('n', '[LSP]h', vim.lsp.buf.hover, bufopts)
           vim.keymap.set('n', '[LSP]t', vim.lsp.buf.type_definition, bufopts)
           vim.keymap.set('n', '[LSP]r', vim.lsp.buf.references, bufopts)
           vim.keymap.set('n', '[LSP]R', vim.lsp.buf.rename, bufopts)
           vim.keymap.set('n', '[LSP]a', vim.lsp.buf.code_action, bufopts)
           vim.keymap.set('n', '[LSP]f', function() vim.lsp.buf.format { async = true } end, bufopts)
           vim.keymap.set('n', '[LSP]I', vim.lsp.buf.implementation, bufopts)
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
     '';
  };
}

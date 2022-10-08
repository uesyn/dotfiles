require("mason").setup()
require("mason-lspconfig").setup()
local lsp_status = require('lsp-status')
lsp_status.register_progress()

vim.opt.completeopt= {"menu", "menuone", "noselect"}

local cmp = require('cmp')
cmp.setup {
  sources = cmp.config.sources({
    {name = 'nvim_lsp'},
  }),
  mapping = {
    ['<C-x>'] = function(fallback)
      if cmp.visible() then
        cmp.abort()
      else
        fallback()
      end
    end,
    ['<C-n>'] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end,
    ['<C-p>'] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end,
    ['<C-f>'] = function(fallback)
      if cmp.visible() then
        cmp.mapping.scroll_docs(4)
      else
        fallback()
      end
    end,
    ['<C-b>'] = function(fallback)
      if cmp.visible() then
        cmp.mapping.scroll_docs(-4)
      else
        fallback()
      end
    end,
    ['<CR>'] = function(fallback)
      if cmp.visible() then
        cmp.mapping.confirm { select = true }
      else
        fallback()
      end
    end,
  },
}

function default_lsp_opts()
    return {
      flags = {
        debounce_text_changes = 250,
      },
      on_attach = function(client, bufnr)
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
        local opts = { noremap=true, silent=true }
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]D', "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]d', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]h', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]t', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]r', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]R', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]a', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]f', '<cmd>lua vim.lsp.buf.format()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]q', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '[LSP]i', "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
      end,
      capabilities = require('cmp_nvim_lsp').update_capabilities(
        lsp_status.capabilities
      )
    }
end

local servers = {"gopls", "rust_analyzer"}

local lspconfig = require('lspconfig')
require('mason-lspconfig').setup_handlers {
  function(server_name)
    local opt = default_lsp_opts()

    for _, s in ipairs(servers) do
      if server_name == s then
        return
      end
    end

    lspconfig[server_name].setup(opt)
  end
}

for _, server_name in ipairs(servers) do
  local opt = default_lsp_opts()

  if server_name == "gopls" then
    opt.settings = {
      cmd = {"gopls"},
      gopls = {
        codelenses = {
          test = true
        }
      }
    }
  end

  lspconfig[server_name].setup(opt)
end

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, { virtual_text = false }
)

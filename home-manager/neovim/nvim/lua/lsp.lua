-- Language Server Configurations
vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = true,
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end

    local bufnr = args.buf

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
    end

    function opts(desc)
      return { desc = desc, noremap = true, silent = true, buffer = bufnr }
    end
    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts("Go to definition"))
    vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end, opts("Go to declarations"))
    vim.keymap.set("n", "gi", function() vim.lsp.buf.implementation() end, opts("Go to implementations"))
    vim.keymap.set("n", "H", function() vim.lsp.buf.hover() end, opts("Displays hover information about the symbol"))
    vim.keymap.set("n", "gr", function() vim.lsp.buf.references() end, opts("Go to references"))
    vim.keymap.set("n", "gt", function() vim.lsp.buf.type_definition() end, opts("Go to type definitions"))
    vim.keymap.set("n", "gs", function() vim.lsp.buf.document_symbol() end, opts("Go to document symbols"))
    vim.keymap.set("i", "<C-l>", function() vim.lsp.buf.signature_help() end, opts("Show signature help"))
    vim.keymap.set("n", "<leader>lR", function() vim.lsp.buf.rename() end, opts("Rename"))
    vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, opts("Format"))
    vim.keymap.set("n", "<leader>la", function() vim.lsp.buf.code_action() end, opts("Code actions"))
    vim.keymap.set("n", "<leader>li", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, opts("Toggle inlay hint"))
  end,
})

-- ref: https://github.com/neovim/neovim/issues/38248
local completion_group = vim.api.nvim_create_augroup('LspCompletionPopup', { clear = true })
local function set_popup_border(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_config(winid, { border = 'rounded' })
  end
end
vim.api.nvim_create_autocmd('CompleteChanged', {
  group = completion_group,
  callback = function()
    vim.schedule(function()
      local data = vim.fn.complete_info({ 'selected' })
      set_popup_border(data.preview_winid)
    end)
  end,
})

local diagnostic_enabled = true
vim.keymap.set("n", "<leader>ll", function()
  diagnostic_enabled = not diagnostic_enabled
  vim.diagnostic.config({
    virtual_lines = diagnostic_enabled,
    virtual_text = not diagnostic_enabled,
  })
end, { desc = "Toggle diagnostic display" })

vim.lsp.enable({'copilot', 'gopls', 'typescript_language_server', 'rust_analyzer', 'phpactor'})

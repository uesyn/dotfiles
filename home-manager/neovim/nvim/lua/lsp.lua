-- Language Server Configurations
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end

    local client = vim.lsp.get_client_by_id(args.data.client_id)

    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, args.buf)
    end

    function opts(desc)
      return { desc = desc, noremap = true, silent = true, buffer = bufnr }
    end
    local bufnr = args.buf
    -- vim.keymap.set("n", "gd", function() lua vim.lsp.buf.definition() end, opts("Go to definition"))
    vim.keymap.set("n", "gd", function() FzfLua.lsp_definitions() end, opts("Go to definition"))
    vim.keymap.set("n", "gD", function() FzfLua.lsp_declarations() end, opts("Go to declarations"))
    vim.keymap.set("n", "gi", function() FzfLua.lsp_implementations() end, opts("Go to implementations"))
    vim.keymap.set("n", "H", function() vim.lsp.buf.hover() end, opts("Displays hover information about the symbol"))
    vim.keymap.set("n", "gr", function() FzfLua.lsp_references() end, opts("Go to references")) -- should add nowait option?
    vim.keymap.set("n", "gt", function() FzfLua.lsp_type_definitions() end, opts("Go to type defenitions"))
    vim.keymap.set("n", "gs", function() FzfLua.lsp_workspace_symbols() end, opts("Go to document symbols"))
    vim.keymap.set("i", "<C-l>", function() vim.lsp.buf.signature_help() end, opts("Show signature help"))
    vim.keymap.set("n", "<leader>lR", function() vim.lsp.buf.rename() end, opts("Rename"))
    vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, opts("Format"))
    vim.keymap.set("n", "<leader>la", function() FzfLua.lsp_code_actions() end, opts("Format"))
    vim.keymap.set("n", "<leader>li", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, opts("Toggle inlay hint"))
  end,
})

vim.lsp.enable({'gopls', 'typescript_language_server', 'rust_analyzer'})

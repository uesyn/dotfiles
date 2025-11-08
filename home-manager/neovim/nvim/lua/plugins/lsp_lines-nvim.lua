return {
  "lsp_lines.nvim",
  event = {
    "LspAttach",
  },
  after = function()
    vim.diagnostic.config({ virtual_text = false })
    require("lsp_lines").setup()
    vim.keymap.set("n", "<Leader>ll", require("lsp_lines").toggle, { desc = "Toggle lsp_lines" })
    require("lsp_lines").toggle()
  end,
}

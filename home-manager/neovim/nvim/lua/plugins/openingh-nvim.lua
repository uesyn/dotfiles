return {
  "openingh.nvim",
  keys = {
    {"<Leader>go", "n"},
    {"<Leader>go", "v"},
  },
  after = function()
    vim.keymap.set("n", "<Leader>go", "<Cmd>OpenInGHFile<CR>", { desc = "Open in Github" })
    vim.keymap.set("v", "<Leader>go", "<Esc><Cmd>'<,'>OpenInGHFile<CR>", { desc = "Open fucusing lines in Github" })
  end,
}

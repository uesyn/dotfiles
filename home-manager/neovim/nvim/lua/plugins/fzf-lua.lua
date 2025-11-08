return {
  "fzf-lua",
  event = {
    "DeferredUIEnter",
  },
  after = function()
    require("fzf-lua").setup()
    vim.keymap.set("n", "<Leader>fg", FzfLua.live_grep, { desc = "Search files with grep and fuzzy finder" })
    vim.keymap.set("n", "<Leader>ff", FzfLua.files, { desc = "Search Lines with fuzzy finder" })
    vim.keymap.set("n", "<Leader>f;", FzfLua.resume, { desc = "Resume fuzzy finder results" })
  end,
}

return {
  "blame.nvim",
  keys = {
    {"<leader>gb", "n"},
  },
  after = function()
    require("blame").setup()
    vim.keymap.set("n", "<leader>gb", "<Cmd>BlameToggle<CR>")
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "blame",
      callback = function()
        vim.bo.buflisted = false
        vim.keymap.set("n", "q", ":clo<CR>", { buffer = true, desc = "Close blame window" })
        vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
      end,
    })
  end,
}

return {
  "barbar.nvim",
  event = {
    "DeferredUIEnter",
  },
  after = function()
    require("barbar").setup({
      ["animation"] = false,
      auto_hide = 0,
      exclude_ft = {'dump'},
    })
    vim.keymap.set("n", "<C-n>", "<Cmd>BufferNext<CR>", { desc = "Go to next buffer" } )
    vim.keymap.set("n", "<C-p>", "<Cmd>BufferPrevious<CR>", { desc = "Go to previous buffer" } )
    vim.keymap.set("n", "<C-q>", "<Cmd>BufferClose<CR>", { desc = "Close current buffer" } )
  end,
}

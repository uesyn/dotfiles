return {
  {
    "blame.nvim",
    after = function()
      require("blame").setup()
      vim.keymap.set("n", "<leader>gb", "<Cmd>BlameToggle<CR>")
      vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("my_blame", { clear = true }),
          pattern = "blame",
          callback = function()
              vim.bo.buflisted = false
              vim.keymap.set("n", "<C-q>", ":clo<CR>", { buffer = true })
              vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
          end,
      })
    end,
    keys = { "<Leader>gb" },
  },
  {
    "gitsigns.nvim",
    after = function()
      require("gitsigns").setup({ ["signs"] = { ["add"] = { ["text"] = "+" }, ["change"] = { ["text"] = "~" } } })
    end,
    event = "BufEnter",
  },
}

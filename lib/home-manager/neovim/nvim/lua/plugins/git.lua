return {
  {
    name = "blame_nvim",
    dir = "@blame_nvim@",
    config = function()
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
    name = "gitsigns_nvim",
    dir = "@gitsigns_nvim@",
    config = function()
      require("gitsigns").setup()
    end,
    event = "BufEnter",
  },

}

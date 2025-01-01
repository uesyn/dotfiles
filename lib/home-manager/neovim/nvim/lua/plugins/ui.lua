return {
  {
    name = "dracula_nvim",
    dir = "@dracula_nvim@",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("dracula")
    end,
  },
  {
    name = "barbar_nvim",
    dir = "@barbar_nvim@",
    dependencies = {
      { name = "nvim_web_devicons", dir = "@nvim_web_devicons@" },
    },
    config = function()
      require("barbar").setup({
        ["animation"] = false,
        auto_hide = 0,
        exclude_ft = {'dump'},
      })
      vim.keymap.set("n", "<C-n>", "<Cmd>BufferNext<CR>")
      vim.keymap.set("n", "<C-p>", "<Cmd>BufferPrevious<CR>")
      vim.keymap.set("n", "<C-q>", "<Cmd>BufferClose<CR>")
    end,
    event = "BufEnter",
  },
  {
    name = "cellwidths_nvim",
    dir = "@cellwidths_nvim@",
    config = function()
      require("cellwidths").setup { name = "default" }
    end,
    event = "VimEnter",
  },
}


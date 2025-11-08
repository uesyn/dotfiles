return {
  "dracula.nvim",
  lazy = false,
  priority = 10,
  after = function()
    vim.cmd.colorscheme("dracula")
  end,
}

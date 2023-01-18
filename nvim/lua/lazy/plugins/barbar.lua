return {
  "romgrk/barbar.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  lazy = false,
  config = function()
    vim.keymap.set('n', '<S-q>', '<Cmd>BufferClose<CR>')
    vim.keymap.set('n', '<C-n>', '<Cmd>BufferNext<CR>')
    vim.keymap.set('n', '<C-p>', '<Cmd>BufferPrevious<CR>')
  end,
}

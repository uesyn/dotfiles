return  {
  "junegunn/fzf",
  dependencies = {
    "junegunn/fzf.vim",
  },
  keys = {"<Leader>fs", "<Leader>ff"},
  config = function()
    vim.keymap.set('n', '<Leader>fs', ":Rg<space>")
    vim.keymap.set('n', '<Leader>ff', "<Cmd>FZF<CR>")
  end,
}

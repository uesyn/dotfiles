return  {
  "tyru/open-browser.vim",
  dependencies = {
    "tyru/open-browser-github.vim",
  },
  keys = {"<Leader>ho", {"<Leader>ho", mode = "v"}},
  config = function()
    vim.keymap.set('n', '<Leader>ho', '<Cmd>OpenGithubFile<CR>')
    vim.keymap.set('v', '<Leader>ho', "<Cmd>'<,'>OpenGithubFile<CR>")
  end,
}

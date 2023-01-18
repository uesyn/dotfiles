return {
  "ojroques/vim-oscyank",
  lazy = false,
  config = function()
    vim.keymap.set('v', '<Leader>y', "<Cmd>OSCYank<CR>")
    vim.g.oscyank_term = 'default'
    vim.g.oscyank_max_length = 1000000
    vim.cmd[[autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif]]
  end,
}

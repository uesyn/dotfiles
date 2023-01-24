return {
  "liuchengxu/vista.vim",
  init = function()
    vim.keymap.set('n', '[LSP]v', "<Cmd>Vista!!<CR>")
    vim.g.vista_default_executive = "vim_lsp"
  end,
}

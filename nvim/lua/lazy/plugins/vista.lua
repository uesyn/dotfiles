return {
  "liuchengxu/vista.vim",
  keys = "[LSP]v",
  config = function()
    vim.keymap.set('n', '[LSP]v', "<Cmd>Vista!!<CR>")
    vim.g.vista_default_executive = "vim_lsp"
  end,
}

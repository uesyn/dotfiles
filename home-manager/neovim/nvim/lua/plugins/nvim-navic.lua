return {
  "nvim-navic",
  lazy = false,
  after = function()
    require('nvim-navic').setup {
      lsp = { auto_attach = true },
    }
  end,
}

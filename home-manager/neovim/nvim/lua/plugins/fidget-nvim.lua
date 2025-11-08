return {
  "fidget.nvim",
  event = {
    "LspAttach",
  },
  after = function()
    require("fidget").setup({})
  end,
}

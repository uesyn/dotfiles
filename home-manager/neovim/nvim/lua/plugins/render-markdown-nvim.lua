return {
  "render-markdown.nvim",
  ft = {
    "Avante",
  },
  after = function()
    require("render-markdown").setup({
      file_types = { "Avante" },
    })
  end,
}

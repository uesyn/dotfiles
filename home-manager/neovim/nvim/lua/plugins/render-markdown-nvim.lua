return {
  "render-markdown.nvim",
  -- Only Avante's chat buffers are rendered as markdown; regular markdown
  -- files stay raw so that the text can be edited.
  ft = {
    "Avante",
  },
  after = function()
    require("render-markdown").setup({
      file_types = { "Avante" },
    })
  end,
}

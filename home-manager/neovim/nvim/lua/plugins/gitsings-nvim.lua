return {
  "gitsigns.nvim",
  event = {
    "BufEnter",
  },
  after = function()
    require("gitsigns").setup()
  end,
}

return {
  "nvim-surround",
  event = {
    "BufEnter",
  },
  after = function()
    require("nvim-surround").setup({})
  end,
}

return {
  "gitsigns.nvim",
  event = {
    "BufEnter",
  },
  after = function()
    -- The statusline reads vim.b.gitsigns_head for the branch name.
    require("gitsigns").setup()
  end,
}

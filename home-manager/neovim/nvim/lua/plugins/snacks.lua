return {
  "snacks.nvim",
  lazy = false,
  priority = 10,
  after = function()
    require("snacks").setup({
      input = { enabled = true },
      notifier = { enabled = true },
    })
  end,
}

return {
  "snacks.nvim",
  lazy = false,
  priority = 10,
  after = function()
    require("snacks").setup({
      input = { enabled = true },
      notifier = { enabled = true },
    })

    local explorer = function()
      Snacks.picker.explorer({
        layout = {
	  preset = "telescope",
	  reverse = false
        },
	auto_close = true,
      })
    end

    vim.keymap.set("n", "<S-f>", explorer, { desc = "Open file explorer" })
  end,
}

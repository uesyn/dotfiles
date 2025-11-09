return {
  "snacks.nvim",
  lazy = false,
  priority = 10,
  after = function()
    require("snacks").setup({
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
	sources = {
	  explorer = {
	    ignored = true,
	    hidden = true,
	  },
	},
      },
    })
    vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { link = "Comment" })

    local explorer = function()
      Snacks.picker.explorer({
        layout = {
	  preset = "telescope",
	  reverse = false
        },
	auto_close = true,
	win = {
	  list = {
	    keys = {
              ["l"] = "confirm",
              ["<CR>"] = "confirm",
              ["h"] = "explorer_close", -- close directory
              ["a"] = "explorer_add",
              ["d"] = "explorer_del",
              ["r"] = "explorer_rename",
              ["c"] = "explorer_copy",
              ["m"] = "explorer_move",
              ["o"] = "explorer_open", -- open with system application
              ["P"] = "toggle_preview",
              ["y"] = { "explorer_yank", mode = { "n", "x" } },
              ["p"] = "explorer_paste",
              ["u"] = "explorer_update",
              ["]g"] = "explorer_git_next",
              ["[g"] = "explorer_git_prev",
              ["]d"] = "explorer_diagnostic_next",
              ["[d"] = "explorer_diagnostic_prev",
              ["]w"] = "explorer_warn_next",
              ["[w"] = "explorer_warn_prev",
              ["]e"] = "explorer_error_next",
              ["[e"] = "explorer_error_prev",
	    },
	  },
	},
      })
    end

    vim.keymap.set("n", "<S-f>", explorer, { desc = "Open file explorer" })
  end,
}

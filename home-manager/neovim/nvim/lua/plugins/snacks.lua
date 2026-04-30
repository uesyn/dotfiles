return {
  "snacks.nvim",
  lazy = false,
  priority = 10,
  after = function()
    require("snacks").setup({
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        layout = {
	  preset = "telescope",
	  reverse = false
        },
	actions = {
	  confirm_or_qflist = function(picker, item, action)
            local sel = picker:selected()
            if #sel > 1 then
	      require("snacks.picker.actions").qflist(picker)
	    else
	      require("snacks.picker.actions").jump(picker, item, action)
            end
          end,
	},
        win = {
          list = {
            keys = {
              ["<CR>"] = "confirm_or_qflist",
            },
          },
          input = {
            keys = {
              ["<CR>"] = "confirm_or_qflist",
            },
          },
	},
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
              ["h"] = "explorer_close", -- close directory
              ["a"] = "explorer_add",
              ["d"] = "explorer_del",
              ["r"] = "explorer_rename",
              ["c"] = "explorer_copy",
              ["m"] = "explorer_move",
              ["o"] = "explorer_open", -- open with system application
              ["P"] = "toggle_preview",
              ["p"] = "explorer_paste",
              ["y"] = { "explorer_yank", mode = { "n", "x" } },
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

    local grep = function()
      Snacks.picker.pick("grep", {})
    end

    local files = function()
      Snacks.picker.pick("files", {})
    end

    local gitbrowse = function()
      Snacks.gitbrowse.open()
    end

    vim.keymap.set("n", "<S-f>", explorer, { desc = "Open file explorer" })
    vim.keymap.set("n", "<Leader>fg", grep, { desc = "Grep files" })
    vim.keymap.set("n", "<Leader>ff", files, { desc = "Find files" })
    vim.keymap.set({ "n", "v" }, "<Leader>go", gitbrowse, { desc = "Open in Github" })
  end,
}

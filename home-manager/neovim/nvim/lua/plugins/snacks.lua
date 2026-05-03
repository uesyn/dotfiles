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
        win = {
          list = {
            keys = {
	      ["q"] = "qflist",
	      ["<C-q>"] = "cancel",
            },
          },
          input = {
            keys = {
	      ["q"] = "qflist",
	      ["<C-q>"] = "cancel",
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
              ["h"] = "explorer_close",
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
	    },
	  },
	},
      })
    end

    local resume = function()
      Snacks.picker.resume()
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

    local ghIssues = function()
      Snacks.picker.gh_issue({ state = "all" })
    end

    local ghPRs = function()
      Snacks.picker.gh_pr({ state = "all" })
    end

    vim.keymap.set("n", "<S-f>", explorer, { desc = "Open file explorer" })
    vim.keymap.set("n", "<leader>fr", resume, { desc = "Resume picker" })
    vim.keymap.set("n", "<leader>fg", grep, { desc = "Grep files" })
    vim.keymap.set("n", "<leader>ff", files, { desc = "Find files" })
    vim.keymap.set({ "n", "v" }, "<leader>go", gitbrowse, { desc = "Open in Github" })
    vim.keymap.set("n", "<leader>fgi", ghIssues, { desc = "Open Github issues" })
    vim.keymap.set("n", "<leader>fgp", ghPRs, { desc = "Open Github pull requests" })
  end,
}

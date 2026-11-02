return {
  "snacks.nvim",
  lazy = false,
  priority = 10,
  after = function()
    -- Telescope-like picker layout: input on top, results below.
    local layout = { preset = "telescope", reverse = false }

    -- `q` sends the selection to the quickfix list, <C-q> aborts.
    local picker_keys = {
      ["q"] = "qflist",
      ["<C-q>"] = "cancel",
    }

    local explorer_keys = {
      ["a"] = "explorer_add",
      ["c"] = "explorer_copy",
      ["d"] = "explorer_del",
      ["h"] = "explorer_close",
      ["m"] = "explorer_move",
      ["o"] = "explorer_open", -- open with the system application
      ["p"] = "explorer_paste",
      ["r"] = "explorer_rename",
      ["u"] = "explorer_update",
      ["P"] = "toggle_preview",
      ["y"] = { "explorer_yank", mode = { "n", "x" } },
    }

    require("snacks").setup({
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        layout = layout,
        win = {
          list = { keys = picker_keys },
          input = { keys = picker_keys },
        },
        sources = {
          explorer = {
            -- Show hidden files and entries that `.gitignore` filters out;
            -- ignored ones are drawn dimmed (see SnacksPickerPathIgnored).
            ignored = true,
            hidden = true,
          },
        },
      },
    })

    vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { link = "Comment" })

    vim.keymap.set("n", "<S-f>", function()
      Snacks.picker.explorer({
        layout = layout,
        auto_close = true,
        win = { list = { keys = explorer_keys } },
      })
    end, { desc = "Open file explorer" })

    vim.keymap.set("n", "<leader>fr", function()
      Snacks.picker.resume()
    end, { desc = "Resume picker" })

    vim.keymap.set("n", "<leader>ff", function()
      Snacks.picker.pick("files", {})
    end, { desc = "Find files" })

    vim.keymap.set("n", "<leader>fg", function()
      Snacks.picker.pick("grep", {})
    end, { desc = "Grep files" })

    vim.keymap.set({ "n", "v" }, "<leader>go", function()
      Snacks.gitbrowse.open()
    end, { desc = "Open in GitHub" })

    vim.keymap.set("n", "<leader>fgi", function()
      Snacks.picker.gh_issue({ state = "all" })
    end, { desc = "Open GitHub issues" })

    vim.keymap.set("n", "<leader>fgp", function()
      Snacks.picker.gh_pr({ state = "all" })
    end, { desc = "Open GitHub pull requests" })
  end,
}

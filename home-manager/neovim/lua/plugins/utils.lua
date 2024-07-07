return {
  {
    "fzf-lua",
    after = function()
      vim.keymap.set("n", "<Leader>fs", "<Cmd>lua require('fzf-lua').live_grep()<CR>")
      vim.keymap.set("n", "<Leader>ff", "<Cmd>lua require('fzf-lua').files()<CR>")
      vim.keymap.set("n", "<Leader>fb", "<Cmd>lua require('fzf-lua').blines()<CR>")
    end,
  },
  {
    "neo-tree.nvim",
    after = function()
      require("neo-tree").setup({
          ["filesystem"] = { ["filtered_items"] = { ["hide_dotfiles"] = false, ["hide_gitignored"] = false } },
          ["popup_border_style"] = "solid",
          ["use_default_mappings"] = false,
          ["window"] = {
              ["mappings"] = {
                  ["<C-q>"] = "close_window",
                  ["<cr>"] = "open",
                  ["<esc>"] = { "revert_preview" },
                  ["?"] = "show_help",
                  ["D"] = "delete",
                  ["F"] = { "add", ["config"] = { ["show_path"] = "absolute" } },
                  ["K"] = { "add_directory", ["config"] = { ["show_path"] = "absolute" } },
                  ["P"] = { "toggle_preview", ["config"] = { ["use_float"] = true } },
                  ["R"] = "rename",
                  ["S"] = { "open_split" },
                  ["c"] = "copy",
                  ["h"] = { "close_node" },
                  ["l"] = { "open" },
                  ["m"] = { "move", ["config"] = { ["show_path"] = "absolute" } },
                  ["p"] = "paste_from_clipboard",
                  ["q"] = "close_window",
                  ["r"] = "refresh",
                  ["s"] = { "open_vsplit" },
                  ["x"] = "cut_to_clipboard",
                  ["y"] = "copy_to_clipboard",
              },
              ["position"] = "float",
          },
      })
      vim.keymap.set("n", "<Leader>fo", "<Cmd>Neotree action=focus reveal toggle<CR>", { silent = true })
    end,
    keys = "<Leader>fo",
  },
  {
    "nvim-surround",
    after = function()
      require("nvim-surround").setup({})
    end,
    event = "BufEnter",
  },
  {
    "openingh.nvim",
    after = function()
      vim.keymap.set("n", "<Leader>ho", "<Cmd>OpenInGHFile<CR>")
      vim.keymap.set("v", "<Leader>ho", "<Esc><Cmd>'<,'>OpenInGHFile<CR>")
    end,
    keys = { { "<Leader>ho", mode = "n" }, { "<Leader>ho", mode = "v" } },
  },
  {
    "nvim-osc52",
    after = function()
      vim.keymap.set("v", "<leader>y", require("osc52").copy_visual)
      vim.api.nvim_create_autocmd("TextYankPost", {
          group = vim.api.nvim_create_augroup("my_nvim_osc52", { clear = true }),
          pattern = "*",
          callback = function()
              if vim.v.event.operator == "y" then
                  require("osc52").copy_register("")
              end
          end,
      })
    end,
    event = "BufEnter",
  },
}

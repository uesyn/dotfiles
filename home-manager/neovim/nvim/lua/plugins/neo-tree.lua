return {
  "neo-tree.nvim",
  cmd = "Neotree",
  beforeAll = function()
    vim.keymap.set("n", "<S-f>", "<Cmd>Neotree toggle reveal<CR>", { desc = "Open file explorer" })
  end,
  after = function()
    require('neo-tree').setup({
      close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
      open_files_do_not_replace_types = { "terminal", "trouble", "qf" }, -- when opening files, do not use windows containing these filetypes or buftypes
      filesystem = {
        filtered_items = {
          visible = true,
        },
      },
      use_default_mappings = false,
      window = {
        position = "float",
        width = 80,
        mappings = {
          ["l"] = "open",
          ["<esc>"] = "cancel", -- close preview or floating neo-tree window
          ["<C-[>"] = "cancel", -- close preview or floating neo-tree window
          ["q"] = "cancel",
          ["P"] = {
            "toggle_preview",
            config = {
              use_float = true,
              use_image_nvim = true,
            },
          },
          ["S"] = "open_split",
          ["s"] = "open_vsplit",
          ["h"] = "close_node",
          ["a"] = {
            "add",
            config = {
              show_path = "none", -- "none", "relative", "absolute"
            },
          },
          ["A"] = "add_directory", -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
          ["D"] = "delete",
          ["R"] = "rename",
          ["y"] = "copy_to_clipboard",
          ["x"] = "cut_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["c"] = {
            "copy",
            config = {
              show_path = "none" -- "none", "relative", "absolute"
            },
          },
          ["m"] = "move", -- takes text input for destination, also accepts the optional config.show_path option like "add".
          ["r"] = "refresh",
          ["?"] = "show_help",
        },
      },
    })
  end,
}

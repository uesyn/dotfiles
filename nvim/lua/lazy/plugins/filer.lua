return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-web-devicons",
    },
    keys = "<Leader>fo",
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.opt.termguicolors = true

      vim.keymap.set('n', '<Leader>fo', '<Cmd>NvimTreeToggle<CR>')

      -- OR setup with some options
      require("nvim-tree").setup({
        disable_netrw = false,
        hijack_cursor = false,
        hijack_netrw = true,
        sort_by = "case_sensitive",
        view = {
          adaptive_size = true,
          mappings = {
            custom_only = true,
            list = {
              { key = "u", action = "dir_up" },
              { key = "<CR>", action = "cd" },
              { key = "l", action = "edit" },
              { key = "h", action = "close_node" },
              { key = "p", action = "preview" },
              { key = "r", action = "refresh" },
              { key = "F", action = "create" },
              { key = "D", action = "remove" },
              { key = "R", action = "full_rename" },
              { key = "c", action = "copy" },
              { key = "x", action = "cut" },
            },
          },
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = false,
        },
      })
    end,
  },

  {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'plenary.nvim',
      'nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    version = "v2.x",
    -- keys = "<Leader>fo",
    config = function()
    end
  },
}

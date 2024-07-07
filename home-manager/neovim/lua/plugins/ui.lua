return {
  {
    "dracula.nvim",
    colorscheme = "dracula",
    after = function()
      vim.cmd.colorscheme("dracula")
    end,
    event = "VimEnter",
  },
  {
    "barbar.nvim",
    after = function()
      require("barbar").setup({
        ["animation"] = false,
        auto_hide = 0,
        exclude_ft = {'dump'},
      })
      vim.keymap.set("n", "<C-n>", "<Cmd>BufferNext<CR>")
      vim.keymap.set("n", "<C-p>", "<Cmd>BufferPrevious<CR>")
      vim.keymap.set("n", "<C-q>", "<Cmd>BufferClose<CR>")
    end,
    event = "BufEnter",
  },
  {
    "cellwidths.nvim",
    after = function()
      -- 'listchars' と 'fillchars' を事前に設定しておくのがお勧めです。
      -- vim.opt.listchars = { eol = "⏎" }
      -- vim.opt.fillchars = { eob = "‣" }
      require("cellwidths").setup {
        name = "default",
        -- name = "empty",          -- 空の設定です。
        -- name = "default",        -- vim-ambiwidth のデフォルトです。
        -- name = "cica",           -- vim-ambiwidth の Cica 用設定です。
        -- name = "sfmono_square",  -- SF Mono Square 用設定です。
      }
    end,
    event = "VimEnter",
  },
}

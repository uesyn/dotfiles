return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },

  {
    "ojroques/vim-oscyank",
    event = "BufReadPre",
    config = function()
      vim.keymap.set('v', '<Leader>y', "<Cmd>OSCYank<CR>")
      vim.g.oscyank_term = 'default'
      vim.g.oscyank_max_length = 1000000
      vim.cmd [[autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif]]
    end,
  },

  {
    "tyru/open-browser.vim",
    dependencies = {
      "tyru/open-browser-github.vim",
    },
    keys = { "<Leader>ho", { "<Leader>ho", mode = "v" } },
    config = function()
      vim.keymap.set('n', '<Leader>ho', '<Cmd>OpenGithubFile<CR>')
      vim.keymap.set('v', '<Leader>ho', "<Cmd>'<,'>OpenGithubFile<CR>")
    end,
  },

  {
    'dhruvasagar/vim-table-mode',
    event = "VeryLazy",
  },

  {
    "simeji/winresizer",
    keys = "<S-w>",
    init = function()
      vim.g.winresizer_start_key = "<S-w>"
    end,
  },

  {
    "junegunn/fzf",
    dependencies = {
      "junegunn/fzf.vim",
    },
    keys = { "<Leader>fs", "<Leader>ff" },
    config = function()
      vim.keymap.set('n', '<Leader>fs', ":Rg<space>")
      vim.keymap.set('n', '<Leader>ff', "<Cmd>FZF<CR>")
    end,
  },

  {
    'echasnovski/mini.bufremove',
    version = '*',
    keys = { "<S-q>" },
    config = function()
      require('mini.bufremove').setup({})
      vim.keymap.set('n', '<S-q>', function() MiniBufremove.delete() end)
    end
  },

  {
    'nvim-lua/plenary.nvim',
  },
}

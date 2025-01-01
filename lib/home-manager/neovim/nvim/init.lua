vim.opt.rtp:prepend("@lazy_nvim@")

require('options')
require('keymaps')
require('autocommands')

require("lazy").setup({
  defaults = { lazy = true },
  rocks = {
    enabled = false,
  },
  performance = {
    rtp = {
      reset = false,
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  spec = "plugins",
})

return {
  "lualine.nvim",
  lazy = false,
  after = function()
    local navic = require("nvim-navic")
    require("lualine").setup({
	options = {
	  disabled_filetypes = {
	    statusline = { "dump" },
	    winbar = { "dump" },
	  },
        },
        sections = {
            lualine_c = {
                { "navic" }
            }
        },
    })
  end,
}

return {
  "lualine.nvim",
  lazy = false,
  after = function()
    local navic = require("nvim-navic")
    require("lualine").setup({
        sections = {
            lualine_c = {
                { "navic" }
            }
        },
    })
  end,
}

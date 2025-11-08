return {
  "winresize.nvim",
  keys = {
    {"<C-h>", "n"},
    {"<C-j>", "n"},
    {"<C-k>", "n"},
    {"<C-l>", "n"},
  },
  after = function()
    vim.keymap.set("n", "<C-h>", function() require("winresize").resize(0, 2, "left") end)
    vim.keymap.set("n", "<C-j>", function() require("winresize").resize(0, 1, "down") end)
    vim.keymap.set("n", "<C-k>", function() require("winresize").resize(0, 1, "up") end)
    vim.keymap.set("n", "<C-l>", function() require("winresize").resize(0, 2, "right") end)
  end,
}

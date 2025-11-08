return {
  "hop.nvim",
  keys = {
    {"<Leader><Leader>", "n"},
    {"<Leader><Leader>", "v"},
  },
  after = function()
    require("hop").setup { keys = 'etovxqpdygfblzhckisuran' }
    vim.keymap.set("n", "<leader><leader>", require('hop').hint_words, { desc = "Hop cursor to hint words" })
    vim.keymap.set("v", "<leader><leader>", function() require('hop').hint_words({ hint_position = require('hop.hint').HintPosition.END }) end, { desc = "Hop cursor to hint words" })
  end,
}

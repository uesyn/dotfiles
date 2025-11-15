return {
  "blink.cmp",
  event = {
    "BufEnter",
  },
  after = function()
    require("blink.cmp").setup({
      keymap = {
        preset = "super-tab",
        ['<CR>'] = { 'accept', 'fallback' },
        ["<C-b>"] = {},
        ["<C-f>"] = {},
      },
      signature = {
        enabled = true,
        window = { border = "single" },
      },
      completion = {
        list = { selection = { preselect = true, auto_insert = false } },
        documentation = { window = { border = "single" } },
        menu = { border = "single" },
      },
      sources = {
        default = { "avante", "lsp", "path", "snippets", "buffer", "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-cmp-copilot",
            score_offset = 100,
            async = true,
          },
          avante = {
            module = 'blink-cmp-avante',
            name = 'Avante',
          }
        },
      },
    })
  end,
}

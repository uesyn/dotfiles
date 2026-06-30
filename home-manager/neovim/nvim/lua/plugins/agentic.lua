return {
  "agentic.nvim",
  keys = {
    {
      "<leader>at",
      function()
        require("agentic").toggle()
      end,
      mode = { "n", "v", "i" },
      desc = "Toggle Agentic Chat",
    },
  },
  after = function()
    require("agentic").setup({
      provider = "opencode-acp",
    })
  end,
}

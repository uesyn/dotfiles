return {
  "avante.nvim",
  event = {
    "DeferredUIEnter",
  },
  after = function()
    require("avante").setup({
      provider = "qwen-cli",
      acp_providers = {
        ["qwen-cli"] = {
          command = "qwen",
          args = { "--experimental-acp" },
          env = {
            NODE_NO_WARNINGS = "1",
	    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY"),
	    OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL"),
	    OPENAI_MODEL = os.getenv("OPENAI_MODEL"),
          },
        },
      },
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "ToJapanese",
      callback = function() require("avante.config").override({system_prompt = "選択範囲を日本語に翻訳して"}) end,
    })
    
    vim.keymap.set("v", "<leader>aj", function() vim.api.nvim_exec_autocmds("User", { pattern = "ToJapanese" }) end, { desc = "avante: Translate to japanese" })
  end,
}

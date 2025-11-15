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
      windows = {
        edit = {
	  start_insert = false,
	},
	ask = {
	  start_insert = false,
	},
      },
    })
  end,
}

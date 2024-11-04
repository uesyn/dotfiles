return {
  {
    name = "copilot_lua",
    dir = "@copilot_lua@",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })
    end,
    event = "InsertEnter",
    cmd = "Copilot",
  },
  {
    name = "copilotchat_nvim",
    dir = "@copilotchat_nvim@",
    dependencies = {
      { name = "copilot_lua", dir = "@copilot_lua@" },
      { name = "plenary_nvim", dir = "@plenary_nvim@" },
    },
    config = function()
      require("CopilotChat").setup({
          prompts = {
              Explain = {
                  prompt = '/COPILOT_EXPLAIN Write an explanation for the active selection as paragraphs of text in Japanese.',
              },
              Review = {
                  prompt = '/COPILOT_REVIEW Review the selected code in Japanese.',
              },
          },
      })
      vim.keymap.set("n", "<Leader>cC", '<Cmd>lua require("CopilotChat").open()<CR>')
      vim.keymap.set("v", "<Leader>cd", '<Cmd>CopilotChatDocs<CR>')
      vim.keymap.set("v", "<Leader>ce", '<Cmd>CopilotChatExplain<CR>')
      vim.keymap.set("v", "<Leader>cr", '<Cmd>CopilotChatReview<CR>')
      vim.keymap.set("v", "<Leader>ct", '<Cmd>CopilotChatTests<CR>')
      vim.keymap.set("n", "<Leader>cc", '<Cmd>CopilotChatCommitStaged<CR>')
      vim.keymap.set("v", "<Leader>cj", '<Cmd>lua require("CopilotChat").ask("Translate to Japanese.", { selection = require("CopilotChat.select").visual })<CR>')
      
      vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("my_copilotchat", { clear = true }),
          pattern = "copilot-chat",
          callback = function()
            vim.keymap.set("n", "<C-q>", '<Cmd>lua require("CopilotChat").toggle()<CR>', { buffer = true })
          end,
      })
    end,
    keys = {
      { "<Leader>cC", mode = "n" },
      { "<Leader>cd", mode = "v" },
      { "<Leader>ce", mode = "v" },
      { "<Leader>cr", mode = "v" },
      { "<Leader>ct", mode = "v" },
      { "<Leader>cc", mode = "n" },
      { "<Leader>cj", mode = "v" },
    },
  },
  {
    name = "nvim_markdown",
    dir = "@nvim_markdown@",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("my_nvim_markdown", { clear = true }),
          pattern = "markdown",
          callback = function()
              vim.keymap.set("n", "<CR>", "<Plug>Markdown_FollowLink", { buffer = true })
              vim.keymap.set("i", "<Tab>", "<Plug>Markdown_Jump", { buffer = true })
              vim.keymap.set("i", "<CR>", "<Plug>Markdown_NewLineBelow", { buffer = true })
          end,
      })
    end,
    ft = "markdown",
  },
}

return {
  "CopilotChat.nvim",
  keys = {
    {"<Leader>cc", mode = {"n", "v"}},
  },
  after = function()
    require("CopilotChat").setup({
      model = 'gpt-4.1',
      window = {
        layout = 'float',
        width = 100, -- Fixed width in columns
        height = 30, -- Fixed height in rows
        border = 'rounded', -- 'single', 'double', 'rounded', 'solid'
        title = '🤖 AI Assistant',
        zindex = 100, -- Ensure window stays on top
      },
      headers = {
        user = '👤 You',
        assistant = '🤖 Copilot',
        tool = '🔧 Tool',
      },
      separator = '━━',
      auto_fold = true, -- Automatically folds non-assistant messages
    })
                                                                                                            
    vim.keymap.set({"n", "v"}, "<Leader>cc", require("CopilotChat").toggle, { desc = "Open Copilot Chat" })
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "copilot-chat",
      callback = function()
        vim.bo.buflisted = false
        vim.keymap.set("n", "<C-r>", require("CopilotChat").reset, { buffer = true, desc = "Reset chat" })
        vim.keymap.set("n", "q", require("CopilotChat").toggle, { buffer = true, desc = "Reset chat" })
        vim.keymap.set("n", "<C-q>", require("CopilotChat").toggle, { buffer = true, desc = "Reset chat" })
        vim.keymap.set("n", "<C-[>", require("CopilotChat").toggle, { buffer = true, desc = "Reset chat" })
        vim.keymap.set("n", "<Esc>", require("CopilotChat").toggle, { buffer = true, desc = "Reset chat" })
        vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
        vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
      end,
    })
  end,
}

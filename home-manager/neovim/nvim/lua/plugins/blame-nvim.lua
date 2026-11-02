return {
  "blame.nvim",
  -- Load trigger: lz.n loads the plugin and replays the key, the mapping
  -- itself is created in after().
  keys = {
    { "<leader>gb", "n" },
  },
  after = function()
    require("blame").setup()

    vim.keymap.set("n", "<leader>gb", "<Cmd>BlameToggle<CR>", { desc = "Toggle git blame" })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "blame",
      callback = function(event)
        vim.bo[event.buf].buflisted = false
        require("util").temp_buffer_keymaps("close")
      end,
    })
  end,
}

return {
  "baleia.nvim",
  -- `dump` buffers are terminal scrollback captured by zellij.
  ft = "dump",
  after = function()
    -- SGR sequences are stripped from the text and rendered as highlights, so
    -- searches and yanks operate on plain text.
    local baleia = require("baleia").setup({
      async = false,
      strip_ansi_codes = true,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("user_baleia", { clear = true }),
      pattern = "dump",
      callback = function(event)
        baleia.once(event.buf)
        -- Colorization changes the buffer text; it is still only a viewer.
        vim.api.nvim_set_option_value("modified", false, { buf = event.buf })
      end,
    })
  end,
}

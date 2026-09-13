return {
  "baleia.nvim",
  ft = "dump",
  after = function()
    -- Strip SGR sequences from the text and represent them as highlights, so
    -- searches and yanks operate on plain text.
    local baleia = require("baleia").setup({
      async = false,
      strip_ansi_codes = true,
    })
    local group = vim.api.nvim_create_augroup("ZellijScrollback", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "dump",
      callback = function(args)
        baleia.once(args.buf)
        -- Colorization changes the buffer text; it is still only a viewer.
        vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
      end,
    })
  end,
}

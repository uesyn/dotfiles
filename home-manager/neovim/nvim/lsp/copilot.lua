return {
  on_init = function()
    local hlc = vim.api.nvim_get_hl(0, { name = "Comment" })
    vim.api.nvim_set_hl(0, "ComplHint", vim.tbl_extend("force", hlc, { underline = true }))
    local hlm = vim.api.nvim_get_hl(0, { name = "MoreMsg" })
    vim.api.nvim_set_hl(0, "ComplHintMore", vim.tbl_extend("force", hlm, { underline = true }))

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local bufnr = args.buf

        vim.lsp.inline_completion.enable(true, { bufnr = bufnr })

        vim.keymap.set("i", "<c-e>", function()
          vim.lsp.inline_completion.get()
          if vim.fn.pumvisible() == 1 then
            return "<c-e>"
          end
        end, { silent = true, expr = true, buffer = bufnr })

        vim.keymap.set("i", "<c-f>", function()
          vim.lsp.inline_completion.select()
        end, { silent = true, buffer = bufnr })
        vim.keymap.set("i", "<c-b>", function()
          vim.lsp.inline_completion.select({ count = -1 * vim.v.count1 })
        end, { silent = true, buffer = bufnr })
      end,
    })

    vim.api.nvim_create_user_command("LspCopilotSignIn", function()
      local client = vim.lsp.get_clients({ name = "copilot" })[1]
      if client then
        client.request_sync("signIn", vim.empty_dict(), 1000, 0)
      end
    end, {})
  end,
}

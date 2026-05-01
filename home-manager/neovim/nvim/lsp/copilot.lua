vim.api.nvim_create_user_command("CopilotSignIn", function()
  local client = vim.lsp.get_clients({ name = "copilot" })[1]
  if not client then
    vim.notify("Copilot LSP is not running", vim.log.levels.WARN)
    return
  end
  -- forked from: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/copilot.lua#L51C1-L83C8
  local signIn = function(err, result)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end
    if result.command then
      local code = result.userCode
      local command = result.command
      vim.fn.setreg('+', code)
      vim.fn.setreg('*', code)
      local continue = vim.fn.confirm(
        'Copied your one-time code to clipboard.\n' .. 'Open the browser to complete the sign-in process?',
        '&Yes\n&No'
      )
      if continue == 1 then
        client:exec_cmd(command, { bufnr = bufnr }, function(cmd_err, cmd_result)
          if cmd_err then
            vim.notify(cmd_err.message, vim.log.levels.ERROR)
            return
          end
          if cmd_result.status == 'OK' then
            vim.notify('Signed in as ' .. cmd_result.user .. '.')
          end
        end)
      end
    end

    if result.status == 'PromptUserDeviceFlow' then
      vim.notify('Enter your one-time code ' .. result.userCode .. ' in ' .. result.verificationUri)
    elseif result.status == 'AlreadySignedIn' then
      vim.notify('Already signed in as ' .. result.user .. '.')
    end
  end

  client:request(
    "signIn",
    vim.empty_dict(),
    signIn
  )
end, {})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client.name ~= "copilot" then
      return
    end

    local hlc = vim.api.nvim_get_hl(0, { name = "Comment" })
    vim.api.nvim_set_hl(0, "ComplHint", vim.tbl_extend("force", hlc, { underline = true }))
    local hlm = vim.api.nvim_get_hl(0, { name = "MoreMsg" })
    vim.api.nvim_set_hl(0,"ComplHintMore", vim.tbl_extend("force", hlm, { underline = true }))

    vim.lsp.inline_completion.enable(true, { bufnr = bufnr })

    vim.keymap.set("i", "<c-e>", function()
      if not vim.lsp.inline_completion.get() then
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

return {
  cmd = { "copilot-language-server", "--stdio" },
  root_markers = { '.git' },
  init_options = {
    editorInfo = {
      name = 'Neovim',
      version = tostring(vim.version()),
    },
    editorPluginInfo = {
      name = 'Neovim',
      version = tostring(vim.version()),
    },
  },
}

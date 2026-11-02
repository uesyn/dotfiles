-- Copilot behaviour: the sign-in command and inline completion. The server
-- itself is declared in nvim/lsp/copilot.lua.

vim.api.nvim_create_user_command("CopilotSignIn", function()
  local client = vim.lsp.get_clients({ name = "copilot" })[1]
  if not client then
    vim.notify("Copilot LSP is not running", vim.log.levels.WARN)
    return
  end

  -- Forked from nvim-lspconfig. The server needs the device flow handled from
  -- the client while the sign-in request is still open.
  -- ref: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/copilot.lua
  local on_sign_in = function(err, result)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end

    -- The device-flow response carries the browser command as well, so it is
    -- offered before the status is reported.
    if result.command then
      vim.fn.setreg("+", result.userCode)
      vim.fn.setreg("*", result.userCode)
      local open_browser = vim.fn.confirm(
        "Copied your one-time code to clipboard.\nOpen the browser to complete the sign-in process?",
        "&Yes\n&No"
      )
      if open_browser == 1 then
        client:exec_cmd(result.command, { bufnr = vim.api.nvim_get_current_buf() }, function(cmd_err, cmd_result)
          if cmd_err then
            vim.notify(cmd_err.message, vim.log.levels.ERROR)
            return
          end
          if cmd_result.status == "OK" then
            vim.notify("Signed in as " .. cmd_result.user .. ".")
          end
        end)
      end
    end

    if result.status == "PromptUserDeviceFlow" then
      vim.notify("Enter your one-time code " .. result.userCode .. " in " .. result.verificationUri)
    elseif result.status == "AlreadySignedIn" then
      vim.notify("Already signed in as " .. result.user .. ".")
    end
  end

  client:request("signIn", vim.empty_dict(), on_sign_in)
end, { desc = "Sign in to GitHub Copilot" })

local group = vim.api.nvim_create_augroup("user_copilot", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= "copilot" then
      return
    end

    local bufnr = event.buf

    -- Underline the suggestion virtual text so it reads as an annotation.
    for target, source in pairs({ ComplHint = "Comment", ComplHintMore = "MoreMsg" }) do
      local hl = vim.api.nvim_get_hl(0, { name = source })
      vim.api.nvim_set_hl(0, target, vim.tbl_extend("force", hl, { underline = true }))
    end

    vim.lsp.inline_completion.enable(true, { bufnr = bufnr })

    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("i", "<C-e>", function()
      if not vim.lsp.inline_completion.get() then
        return "<C-e>"
      end
    end, vim.tbl_extend("force", opts, { expr = true, desc = "Dismiss inline completion" }))

    vim.keymap.set("i", "<C-f>", function()
      vim.lsp.inline_completion.select()
    end, vim.tbl_extend("force", opts, { desc = "Accept inline completion" }))

    vim.keymap.set("i", "<C-b>", function()
      vim.lsp.inline_completion.select({ count = -1 * vim.v.count1 })
    end, vim.tbl_extend("force", opts, { desc = "Accept inline completion line" }))
  end,
})

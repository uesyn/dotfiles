-- Language client wiring: diagnostics, buffer keymaps, completion popup and
-- progress messages. The servers themselves are declared in nvim/lsp/*.lua.

local group = vim.api.nvim_create_augroup("user_lsp", { clear = true })

-- Diagnostics: render the message above the line instead of inline text.
local diagnostic_display = { virtual_text = false, virtual_lines = true }
vim.diagnostic.config(diagnostic_display)

vim.keymap.set("n", "<leader>ll", function()
  diagnostic_display.virtual_lines = not diagnostic_display.virtual_lines
  diagnostic_display.virtual_text = not diagnostic_display.virtual_lines
  vim.diagnostic.config(diagnostic_display)
end, { desc = "Toggle diagnostic display" })

-- Buffer-local keymaps created for every attached language server.
-- Entry format: { mode, lhs, rhs, desc }
local function format_buffer()
  vim.lsp.buf.format({ async = true })
end

local function toggle_inlay_hints()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end

local buffer_keymaps = {
  { "n", "gd", vim.lsp.buf.definition, "Go to definition" },
  { "n", "gD", vim.lsp.buf.declaration, "Go to declaration" },
  { "n", "gi", vim.lsp.buf.implementation, "Go to implementation" },
  { "n", "gt", vim.lsp.buf.type_definition, "Go to type definition" },
  { "n", "gr", vim.lsp.buf.references, "Go to references" },
  { "n", "gs", vim.lsp.buf.document_symbol, "Go to document symbols" },
  { "n", "H", vim.lsp.buf.hover, "Hover documentation" },
  { "i", "<C-l>", vim.lsp.buf.signature_help, "Signature help" },
  { "n", "<leader>lR", vim.lsp.buf.rename, "Rename symbol" },
  { "n", "<leader>la", vim.lsp.buf.code_action, "Code action" },
  { "n", "<leader>lf", format_buffer, "Format buffer" },
  { "n", "<leader>li", toggle_inlay_hints, "Toggle inlay hints" },
}

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then
      return
    end

    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
    end

    for _, keymap in ipairs(buffer_keymaps) do
      local mode, lhs, rhs, desc = keymap[1], keymap[2], keymap[3], keymap[4]
      vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, silent = true, desc = desc })
    end
  end,
})

-- The completion popup has no option for its border, so patch it whenever the
-- popup changes.
-- ref: https://github.com/neovim/neovim/issues/38248
local function set_popup_border(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_config(winid, { border = "rounded" })
  end
end

vim.api.nvim_create_autocmd("CompleteChanged", {
  group = group,
  callback = function()
    vim.schedule(function()
      local info = vim.fn.complete_info({ "selected" })
      set_popup_border(info.preview_winid)
    end)
  end,
})

-- Mirror `$/progress` notifications to the command line.
vim.api.nvim_create_autocmd("LspProgress", {
  group = group,
  callback = function(event)
    local params = event.data.params
    local value = params.value
    vim.api.nvim_echo({ { value.message or "done" } }, false, {
      id = "lsp." .. params.token,
      kind = "progress",
      source = "vim.lsp",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
  end,
})

-- Each name must match a file in nvim/lsp/.
vim.lsp.enable({
  "copilot",
  "gopls",
  "phpactor",
  "pyright",
  "rust_analyzer",
  "typescript_language_server",
})

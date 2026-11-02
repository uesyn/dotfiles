local M = {}

-- Keymaps shared by temporary, read-only windows (quickfix, blame, ...).
-- `close` is the command bound to <C-q>; the quickfix list needs :cclose.
function M.temp_buffer_keymaps(close)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
  end

  map("<C-q>", "<Cmd>" .. close .. "<CR>", "Close window")
  map("<C-n>", "<Nop>", "Disabled: next buffer")
  map("<C-p>", "<Nop>", "Disabled: previous buffer")
end

return M

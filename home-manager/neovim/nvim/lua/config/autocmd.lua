local group = vim.api.nvim_create_augroup("user_autocmd", { clear = true })

-- Yanking into the unnamed register also syncs the system clipboard (OSC52).
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    local event = vim.v.event
    if event.operator == "y" and event.regname == "" then
      vim.fn.setreg("+", event.regcontents, event.regtype)
    end
  end,
})

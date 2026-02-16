vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.bo.buflisted = false
    vim.keymap.set("n", "<C-q>", "<Cmd>clo<CR>", { desc = "Close quickfix", buffer = true })
    vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
    vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
  end,
})

-- When yanked, sync system clipboard with OSC52
vim.api.nvim_create_autocmd('TextYankPost', {
  pattern = '*',
  callback = function()
    event = vim.v.event
    if event.operator == 'y' and event.regname == '' then
      vim.fn.setreg('+', event.regcontents, event.regtype)
    end
  end,
})

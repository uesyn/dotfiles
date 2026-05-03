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

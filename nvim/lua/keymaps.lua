local M = {}

function M.setup()
  vim.api.nvim_create_augroup('my_quickfix', {})
  vim.api.nvim_create_autocmd("FileType", {
    group = 'my_quickfix',
    pattern = 'qf',
    callback = function()
      vim.bo.buflisted = false
      vim.keymap.set('n', 'qq', ':clo<CR>', { buffer = true })
      vim.keymap.set('n', '<C-n>', '<Nop>', { buffer = true })
      vim.keymap.set('n', '<C-p>', '<Nop>', { buffer = true })
    end
  })

  vim.g.mapleader = " "
  vim.keymap.set('n', '<Leader>', '<Nop>')
  vim.keymap.set('n', 'ZZ', '<Nop>')
  vim.keymap.set('n', 'ZQ', '<Nop>')
  vim.keymap.set('n', 'q', '<Nop>')
  vim.keymap.set('n', 'Q', '<Nop>')
  vim.keymap.set('n', '<S-l>', '<C-w>l')
  vim.keymap.set('n', '<S-h>', '<C-w>h')
  vim.keymap.set('n', '<S-k>', '<C-w>k')
  vim.keymap.set('n', '<S-j>', '<C-w>j')

  -- keymap prefix
  vim.keymap.set('n', '[LSP]', '<Nop>')
  vim.keymap.set('n', '<Leader>l', '[LSP]', { remap = true })
  vim.keymap.set('n', '[GIT]', '<Nop>')
  vim.keymap.set('n', '<Leader>g', '[GIT]', { remap = true })
  vim.keymap.set('n', '[BUFFER]', '<Nop>')
  vim.keymap.set('n', '<Leader>g', '[BUFFER]', { remap = true })
end

return M

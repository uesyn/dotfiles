local M = {}

function M.setup()
  vim.api.nvim_create_user_command('TrimSpaces', function() vim.api.nvim_command([[%s/\s\+$//e]]) end, { force = true })
end

return M

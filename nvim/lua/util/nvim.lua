local M = {}

M.packadd = function(package)
  vim.cmd("packadd! " .. package)
end

return M

local M = {}

local os_name = vim.loop.os_uname().sysname

M.is_mac = function()
  return os_name == 'Darwin'
end

M.is_linux = function()
  return os_name == 'Linux'
end

M.is_windows = function()
  return os_name == 'Windows'
end

return M

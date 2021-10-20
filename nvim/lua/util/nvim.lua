local M = {}

M.create_augroups = function(definitions)
  for group_name, definition in pairs(definitions) do
    vim.api.nvim_command('augroup '..group_name)
    vim.api.nvim_command('autocmd!')
    for _, def in ipairs(definition) do
      local command = table.concat(vim.tbl_flatten{'autocmd', def}, ' ')
      vim.api.nvim_command(command)
    end
    vim.api.nvim_command('augroup END')
  end
end

M.set_runtimepath = function(path)
  local paths = require('util.string').split(vim.o.runtimepath, ',')
  for _, p in ipairs(paths) do
    if p == path then
      return
    end
  end

  vim.o.runtimepath = vim.o.runtimepath .. ',' .. path

  return
end

M.set_packpath = function(path)
  local paths = require('util.string').split(vim.o.packpath, ',')
  for _, p in ipairs(paths) do
    if p == path then
      return
    end
  end

  vim.o.packpath = path .. ',' .. vim.o.packpath
  return
end

M.packadd = function(package)
  vim.cmd("packadd " .. package)
end

return M

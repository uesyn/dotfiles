local M = {}

local path = require("util.path")

if vim.g.packin_dir == nil then
  vim.g.packin_dir = vim.fn.expand("~/.config/nvim/packin")
end

function file_exists(name)
   local f = io.open(name,"r")
   if f ~= nil then
     io.close(f)
     return true
   else
     return false
   end
end

function load_config_file(filename)
  local fpath = path.join(vim.g.packin_dir, "config", filename)
  load_config_or_setup_file(fpath)
end

function load_setup_file(filename)
  local fpath = path.join(vim.g.packin_dir, "setup", filename)
  load_config_or_setup_file(fpath)
end

function load_config_or_setup_file(file)
  if not file_exists(file) then
    error(file .. ": file not found")
  end

  if string.len(file) <= 3 then
    error(file .. ": file must be vimscript or lua file")
  end

  if string.sub(file, -3) == "vim" then
    vim.cmd('source ' .. file)
    return
  end

  if string.sub(file, -3) == "lua" then
    vim.cmd('luafile ' .. file)
    return
  end

  error(file .. ": unsupported file")
end

M.load = function(plugins, opts)
  if opts ~= nil and opts.setup ~= nil then
    load_setup_file(opts.setup)
  end

  for i, plugin in ipairs(plugins) do
    vim.cmd("packadd! " .. plugin)
  end

  if opts ~= nil and opts.config ~= nil then
    load_config_file(opts.config)
  end
end

return M

local M = {}

function M.setup()
  local lazyversion = "v10.15.1"
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=" .. lazyversion,
      lazypath,
    })
  end

  -- if in headless mode, sync lazy.nvim version.
  if vim.api.nvim_list_uis()[1] == nil then
    local current_tag = vim.fn.system({
      "git",
      "-C",
      lazypath,
      "tag",
      "-l",
      lazyversion,
    })

    if current_tag == '' then
      vim.fn.system({
        "git",
        "-C",
        lazypath,
        "fetch",
      })
    end

    vim.fn.system({
      "git",
      "-C",
      lazypath,
      "checkout",
      lazyversion,
    })
  end

  vim.opt.rtp:prepend(lazypath)
  local plugins = {
    {
      "folke/lazy.nvim",
      lazy = false,
      version = lazyversion,
    },
    {
      import = "lazy.plugins"
    },
  }
  local lazy = require("lazy")
  lazy.setup({
    spec = plugins,
    change_detection = {
      enabled = true,
      notify = false,
    },
    install = {
      missing = true,
      colorscheme = { 'default' },
    },
  })
end

return M

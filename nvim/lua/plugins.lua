local lazyversion = "v9.3.1"
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
require("lazy").setup(plugins)

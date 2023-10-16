local M = {}

function M.setup()
  vim.opt.encoding = 'UTF-8'
  vim.scriptencoding = 'utf-8'
  vim.opt.backspace= {"indent", "eol", "start"}
  vim.opt.display = {"lastline", "msgsep"}
  vim.opt.hidden = true
  vim.opt.hlsearch = true
  vim.opt.linebreak = true
  vim.opt.ruler = true
  vim.opt.termguicolors = true
  vim.opt.wildmenu = true
  vim.opt.wildmode = "full"
  vim.opt.inccommand = "split"
  vim.opt.maxmempattern = 20000
  vim.opt.updatetime = 100
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.showcmd = false
  vim.opt.showmode = false
  vim.opt.emoji = true
  vim.opt.ambiwidth = "single"
  vim.opt.fileformats = {"unix", "dos", "mac"}
  vim.opt.foldcolumn = "0"
  vim.opt.signcolumn = "yes"
  vim.opt.laststatus = 3
  vim.opt.showtabline = 2
  vim.opt.breakindent = true
  --  vim.opt.binary = true
  --  vim.opt.eol = false

  vim.g.netrw_fastbrowse = 0

  -- set t_ut=
  -- set t_8f=\<Esc>38;2;%lu;%lu;%lum
  -- set t_8b=\<Esc>48;2;%lu;%lu;%lum
end

return M

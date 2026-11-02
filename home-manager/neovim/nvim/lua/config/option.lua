-- Editor options, grouped by concern. Only the values whose reason is not
-- obvious from the option name carry a comment.

-- Globals --------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.netrw_fastbrowse = 0
vim.g.clipboard = "osc52" -- yank/paste through the terminal, works over ssh

-- Display --------------------------------------------------------------------
vim.opt.ambiwidth = "single"
vim.opt.breakindent = true
vim.opt.emoji = true
vim.opt.foldcolumn = "0"
vim.opt.laststatus = 3 -- one global statusline
vim.opt.number = true
vim.opt.pumborder = "rounded"
vim.opt.relativenumber = true
vim.opt.showcmd = false
vim.opt.showmode = false -- the mode is in the statusline
vim.opt.showtabline = 2 -- the tabline is the buffer list (barbar.nvim)
vim.opt.signcolumn = "yes"
vim.opt.synmaxcol = 320 -- stop highlighting pathological single-line files
vim.opt.termguicolors = true
vim.opt.winborder = "rounded"

-- Editing --------------------------------------------------------------------
vim.opt.fileformats = { "unix", "dos", "mac" }
vim.opt.inccommand = "split" -- preview :s in a split window instead of inline
vim.opt.maxmempattern = 20000
vim.opt.updatetime = 100 -- gitsigns and diagnostics react immediately
vim.opt.wildmode = "full"

-- Completion -----------------------------------------------------------------
vim.opt.autocomplete = true
vim.opt.autocompletedelay = 150
vim.opt.complete = { "o" }
vim.opt.completeopt = { "menu", "fuzzy", "popup", "noselect", "noinsert" }

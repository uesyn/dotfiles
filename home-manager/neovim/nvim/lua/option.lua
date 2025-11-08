-- Set up globals
vim.g["loaded_perl_provider"] = 0
vim.g["loaded_python_provider"] = 0
vim.g["loaded_ruby_provider"] = 0
vim.g["mapleader"] = " "
vim.g["netrw_fastbrowse"] = 0
vim.g["clipboard"] = 'osc52'

-- Set up options
vim.opt["ambiwidth"] = "single"
vim.opt["breakindent"] = true
vim.opt["emoji"] = true
vim.opt["fileformats"] = { "unix", "dos", "mac" }
vim.opt["foldcolumn"] = "0"
vim.opt["inccommand"] = "split"
vim.opt["laststatus"] = 3
vim.opt["maxmempattern"] = 20000
vim.opt["number"] = true
vim.opt["relativenumber"] = true
vim.opt["showcmd"] = false
vim.opt["showmode"] = false
vim.opt["showtabline"] = 2
vim.opt["signcolumn"] = "yes"
vim.opt["synmaxcol"] = 320
vim.opt["updatetime"] = 100
vim.opt["wildmode"] = "full"
vim.opt["termguicolors"] = true
vim.opt["winborder"] = 'rounded'
vim.opt["completeopt"] = { 'menu', 'popup', 'noselect' }

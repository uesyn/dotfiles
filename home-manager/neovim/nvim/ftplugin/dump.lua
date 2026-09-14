vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.winbar = ""
vim.opt_local.statusline = "%{%&filetype ==# 'dump' ? '%#StatusMode# SCROLL MODE %*' : v:lua.statusline()%}"

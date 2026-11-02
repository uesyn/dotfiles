-- Dump buffers are read-only viewers of terminal output (see
-- lua/plugins/baleia-nvim.lua): no line numbers, no signs, no winbar.
vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.signcolumn = "no"
vim.opt_local.winbar = ""
-- Window-local, so it outlives this buffer: the ternary restores the global
-- statusline as soon as another file is shown in the window.
vim.opt_local.statusline =
  "%{%&filetype ==# 'dump' ? '%#StatusMode# SCROLL MODE %*' : v:lua.statusline()%}"

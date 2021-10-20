autocmd BufRead,BufNewFile *.dump set filetype=zellij-terminal

autocmd FileType zellij-terminal setlocal nonumber
autocmd FileType zellij-terminal setlocal norelativenumber
autocmd FileType zellij-terminal setlocal signcolumn=no

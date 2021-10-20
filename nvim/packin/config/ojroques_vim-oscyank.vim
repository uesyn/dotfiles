vnoremap <Leader>y :OSCYank<CR>
let g:oscyank_term = 'default'
let g:oscyank_max_length = 1000000
autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif

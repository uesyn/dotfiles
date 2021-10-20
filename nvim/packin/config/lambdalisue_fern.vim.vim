augroup my_fern
  autocmd!
  autocmd FileType fern nmap <buffer> D <Plug>(fern-action-remove)
  autocmd FileType fern nmap <buffer> R <Plug>(fern-action-rename)
  autocmd FileType fern nmap <buffer> r <Plug>(fern-action-reload:all)
  autocmd FileType fern nmap <buffer> F <Plug>(fern-action-new-file)
  autocmd FileType fern nmap <buffer> K <Plug>(fern-action-new-dir)
  autocmd FileType fern nmap <buffer> l <Plug>(fern-action-open-or-expand)
  autocmd FileType fern nmap <buffer> h <Plug>(fern-action-collapse)
  autocmd FileType fern nmap <buffer> <CR> <Plug>(fern-action-open:select)

  autocmd FileType fern nnoremap <buffer> <C-n> <Nop>
  autocmd FileType fern nnoremap <buffer> <C-p> <Nop>
  autocmd FileType fern nnoremap <buffer> <S-q> <Nop>
augroup END

nnoremap <silent> <leader>fo :Fern . -drawer -toggle<CR>

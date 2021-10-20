nmap [LSP]v :Vista<CR>

let g:vista_fzf_preview = ['right:50%']
let g:vista_sidebar_width = 30
let g:vista_stay_on_open = 0
let g:vista_executive_for = {
  \ 'go': 'vim_lsp',
  \ 'rust': 'vim_lsp',
  \ 'typescript': 'vim_lsp',
  \ 'javascript': 'vim_lsp',}

augroup my_vista
  autocmd!
  autocmd FileType vista_kind set nobuflisted
  autocmd FileType vista_kind nnoremap <buffer> q <Nop>
  autocmd FileType vista_kind nnoremap <buffer> qq <Nop>
augroup END

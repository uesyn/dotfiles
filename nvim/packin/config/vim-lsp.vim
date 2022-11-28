set signcolumn=yes
set omnifunc=lsp#complete

nmap [LSP]D <plug>(lsp-declaration)
nmap [LSP]d <plug>(lsp-definition)
nmap [LSP]h <plug>(lsp-hover)
nmap [LSP]t <plug>(lsp-type-definition)
nmap [LSP]r <plug>(lsp-references)
nmap [LSP]R <plug>(lsp-rename)
nmap [LSP]a <plug>(lsp-code-action)
nmap [LSP]f <plug>(lsp-document-format)
nmap [LSP]q <plug>(lsp-document-diagnostics)
nmap [LSP]i :LspCodeActionSync source.organizeImports<CR>
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

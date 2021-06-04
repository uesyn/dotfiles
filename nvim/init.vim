if &compatible
  set nocompatible
endif

let mapleader = "\<Space>"
set number
set hidden
set hlsearch
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
set backspace=2
set directory=~/.cache/vim/swap
set cindent
set t_ut=
set encoding=UTF-8
set autoindent
set cursorline
set linebreak
set display+=lastline
set ruler
set wildmenu
set wildmode=full

" leader
map <Space> <Nop>

" keymap
nnoremap ZZ <Nop>
nnoremap ZQ <Nop>
nnoremap q <Nop>
nnoremap Q <Nop>

nnoremap <silent> <S-l> <C-w>l
nnoremap <silent> <S-h> <C-w>h
nnoremap <silent> <S-k> <C-w>k
nnoremap <silent> <S-j> <C-w>j

" buffer
nnoremap <silent> <C-n> :NextBuffer<CR>
nnoremap <silent> <C-p> :PreviousBuffer<CR>
nnoremap <silent> qq :CloseTabOrBuffer<CR>

function! s:copy()
  call system('clip', @0)
endfunction

nnoremap <silent> <Leader>y :call <SID>copy()<CR>

" tabline
set showtabline=2
set tabline=%!my#tabline#make_tab_line()

" statusline
augroup my_statusline
  autocmd! *
  autocmd BufEnter * call my#statusline#set_status_line()
augroup END

" netrw
let g:netrw_fastbrowse = 0 "to close netrw when open a file

" dein
let g:cache_home = empty($XDG_CACHE_HOME) ? expand('~/.cache') : $XDG_CACHE_HOME
let s:dein_dir = g:cache_home . '/dein'
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'
if !isdirectory(s:dein_repo_dir)
  call system('git clone --depth=1 https://github.com/Shougo/dein.vim ' . shellescape(s:dein_repo_dir))
endif
let &runtimepath = s:dein_repo_dir .",". &runtimepath
let s:toml_file = fnamemodify(expand('<sfile>'), ':h').'/dein.toml'
if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)
  call dein#load_toml(s:toml_file)
  call dein#end()
  call dein#save_state()
endif

if has('vim_starting') && dein#check_install()
  call dein#install()
endif

" kubernetes
nnoremap [KUBERNETES] <Nop>
map <Leader>k [KUBERNETES]
noremap <silent> [KUBERNETES]a :'<,'>KubectlApply<CR>
noremap <silent> [KUBERNETES]D :'<,'>KubectlDelete<CR>
noremap <silent> [KUBERNETES]d :'<,'>KubectlDescribe<CR>
noremap <silent> [KUBERNETES]g :'<,'>KubectlGet<CR>

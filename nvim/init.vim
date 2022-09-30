set encoding=UTF-8
scriptencoding utf-8
set noerrorbells
set novisualbell t_vb=
set backspace=2
" set cursorline
set display=lastline,msgsep
set hidden
set hlsearch
set linebreak
set ruler
set termguicolors
set wildmenu
set wildmode=full
set inccommand=split
set maxmempattern=20000
set updatetime=100
set number
set relativenumber
set noshowcmd
set noshowmode
set emoji
set ambiwidth=single
set fileformats=unix,dos,mac
set foldcolumn=0
set signcolumn=yes
set laststatus=2 "always show statusline
set showtabline=2 "always show tabline
set breakindent
set binary noeol
" set clipboard+=unnamedplus

set t_ut=
set t_8f=\<Esc>38;2;%lu;%lu;%lum
set t_8b=\<Esc>48;2;%lu;%lu;%lum

let g:netrw_fastbrowse=0

augroup my_quickfix
  autocmd!
  autocmd FileType qf set nobuflisted
  autocmd FileType qf nnoremap qq :q<CR>
  autocmd FileType qf nnoremap <buffer> <C-n> <Nop>
  autocmd FileType qf nnoremap <buffer> <C-p> <Nop>
augroup END

" keymaps
let mapleader = "\<Space>"
nnoremap <Leader> <Nop>
nnoremap ZZ <Nop>
nnoremap ZQ <Nop>
nnoremap q <Nop>
nnoremap Q <Nop>

nnoremap <silent> <S-l> <C-w>l
nnoremap <silent> <S-h> <C-w>h
nnoremap <silent> <S-k> <C-w>k
nnoremap <silent> <S-j> <C-w>j

nnoremap <silent> <C-p> :bp<CR>
nnoremap <silent> <C-n> :bn<CR>

" show current file fullpath
nnoremap <Leader><Space> :echo expand('%:p')<CR>

" keymap prefix
map [LSP] <Nop>
map <Leader>l [LSP]
map [MEMO] <Nop>
map <Leader>m [MEMO]
map [GIT] <Nop>
map <Leader>g [GIT]
map [BUFFER] <Nop>
map <Leader>b [BUFFER]

command! TrimSpaces call execute('%s/\s\+$//e')

" load plugins
let g:packin_dir = expand("<sfile>:p:h") .. '/packin'
call packin#begin()

" tweeks
call Packin({'name': 'simeji_winresizer', 'setup': 'simeji_winresizer.vim'})
call Packin({'name': 'ojroques_vim-oscyank', 'config': 'ojroques_vim-oscyank.vim'})
call Packin({'name': 'antoinemadec_FixCursorHold.nvim', 'config': 'antoinemadec_FixCursorHold.nvim.vim'})

" buffer
call Packin({'name': 'moll_vim-bbye', 'config': 'moll_vim-bbye.vim'})

" colorscheme
" call Packin({'name': 'gruvbox-community_gruvbox', 'config': 'gruvbox-community_gruvbox.vim'})
call Packin({'name': 'dracula_vim', 'config': 'dracula_vim.vim'})
" overwrite background color with terminal background color
augroup my_highlight
  autocmd!
  autocmd colorscheme * hi Normal guibg=NONE guifg=NONE ctermfg=NONE ctermbg=NONE
augroup END

" git
call Packin({'name': 'mhinz_vim-signify'})

" web browser
call Packin({'name': 'tyru_open-browser.vim'})
call Packin({'name': 'tyru_open-browser-github.vim', 'after': 'tyru_open-browser.vim', 'config': 'tyru_open-browser-github.vim.vim'})

" fuzzy finder
call Packin({'name': 'junegunn_fzf'})
call Packin({'name': 'junegunn_fzf.vim', 'after': 'junegunn_fzf', 'config': 'junegunn_fzf.vim.vim'})

" finder
call Packin({'name': 'lambdalisue_nerdfont.vim'})
call Packin({'name': 'lambdalisue_fern.vim', 'setup': 'lambdalisue_fern.vim.vim', 'config': 'lambdalisue_fern.vim.vim'})
call Packin({'name': 'lambdalisue_fern-renderer-nerdfont.vim', 'after': 'lambdalisue_fern.vim', 'setup': 'lambdalisue_fern-renderer-nerdfont.vim.vim'})
call Packin({'name': 'lambdalisue_fern-git-status.vim', 'after': 'lambdalisue_fern.vim'})
call Packin({'name': 'lambdalisue_glyph-palette.vim', 'after': 'lambdalisue_fern.vim', 'config': 'lambdalisue_glyph-palette.vim.vim'})

" table
call Packin({'name': 'dhruvasagar_vim-table-mode'})

" lsp
call Packin({'name': 'prabirshrestha_vim-lsp', 'setup': 'prabirshrestha_vim-lsp.vim', 'config': 'prabirshrestha_vim-lsp.vim'})
call Packin({'name': 'mattn_vim-lsp-settings', 'after': 'prabirshrestha_vim-lsp'})
call Packin({'name': 'prabirshrestha_asyncomplete.vim'})
call Packin({'name': 'prabirshrestha_asyncomplete-lsp.vim', 'after': ['prabirshrestha_asyncomplete.vim', 'prabirshrestha_vim-lsp']})
call Packin({'name': 'liuchengxu_vista.vim', 'after': 'prabirshrestha_vim-lsp', 'config': 'liuchengxu_vista.vim.vim'})

" filetype
call Packin({'name': 'hashivim_vim-terraform'})
call Packin({'name': 'plasticboy_vim-markdown', 'config': 'plasticboy_vim-markdown.vim'})
call Packin({'name': 'elzr_vim-json', 'config': 'elzr_vim-json.vim'})

" statusline
call Packin({'name': 'mengelbrecht_lightline-bufferline', 'config': 'mengelbrecht_lightline-bufferline.vim', 'setup': 'mengelbrecht_lightline-bufferline.vim', 'after': 'lambdalisue_nerdfont.vim'})
call Packin({'name': 'itchyny_lightline.vim', 'config': 'itchyny_lightline.vim.vim', 'after': 'mengelbrecht_lightline-bufferline'})

call packin#end()

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
nnoremap <silent> <C-n> :bnext<CR>
nnoremap <silent> <C-p> :bprevious<CR>

function! s:copy()
  call system('clip', @0)
endfunction

nnoremap <silent> <Leader>y :call <SID>copy()<CR>

" tabline
function! TabLabel(n)
  let hi = a:n is bufnr() ? '%#TabLineSel#' : '%#TabLine#'
  let label = hi . bufname(a:n) . '%#TabLineFill#%T'
  return label
endfunction

function! MakeTabLine()
  let s = ""
  let tabnum = tabpagenr('$')
  if tabnum > 1
    let s .= '%#TabLineSel#' . '[CODE JUMP ' . (tabnum - 1) . ']' . '%#TabLineFill#%T '
  endif

  let buffers = filter(range(1, bufnr('$')), 'buflisted(v:val)')
  let labels = map(buffers, 'TabLabel(v:val)')
  return s . ' ' . join(labels, " | ")
endfunction

set showtabline=2
set tabline=%!MakeTabLine()

""" vim-plug config
let vim_cache = expand('~/.cache/nvim')
let vim_plug_dir = expand(vim_cache . '/vim-plug')
if !isdirectory(vim_plug_dir)
  call system('curl -fLo ' . vim_plug_dir . '/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
  echo "Downlaoded vim-plug"
endif
let &runtimepath .= ',' .vim_plug_dir

" check the specified plugin is installed
function! s:is_plugged(name)
    if exists('g:plugs') && has_key(g:plugs, a:name) && isdirectory(g:plugs[a:name].dir)
        return 1
    else
        return 0
    endif
endfunction

call plug#begin(vim_cache . '/plugged')
  " Syntax
  Plug 'stephpy/vim-yaml'

  " Search
  Plug 'junegunn/fzf'
  Plug 'junegunn/fzf.vim'

  " Filer
  Plug 'lambdalisue/nerdfont.vim'
  Plug 'lambdalisue/fern-renderer-nerdfont.vim'
  Plug 'lambdalisue/glyph-palette.vim'
  Plug 'lambdalisue/fern-git-status.vim'
  Plug 'lambdalisue/fern.vim'

  " UI
  Plug 'morhetz/gruvbox'

  " Git
  Plug 'tpope/vim-fugitive'
  Plug 'junegunn/gv.vim'
  Plug 'airblade/vim-gitgutter'

  Plug 'tyru/open-browser.vim'
  Plug 'tyru/open-browser-github.vim'

  " Tweak
  Plug 'rbgrouleff/bclose.vim', { 'on': 'Bclose' }
  Plug 'haya14busa/incsearch.vim'
  Plug 'simeji/winresizer'
  Plug 'lambdalisue/suda.vim'

  " Markdown
  Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

  " Lsp
  Plug 'liuchengxu/vista.vim'
  if executable("node")
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    " Coc Extentions
    if executable("yarn")
      Plug 'josa42/coc-go', {'do': 'yarn install --forzen-lockfile'}
      Plug 'neoclide/coc-json', {'do': 'yarn install --forzen-lockfile'}
      Plug 'neoclide/coc-yaml', {'do': 'yarn install --forzen-lockfile'}
      Plug 'neoclide/coc-tsserver', {'do': 'yarn install --forzen-lockfile'}
      Plug 'neoclide/coc-tabnine', {'do': 'yarn install --forzen-lockfile'}
    endif
  endif

call plug#end()

if s:is_plugged("nerdfont.vim")
  let g:fern#renderer = "nerdfont"
endif

if s:is_plugged("glyph-palette.vim")
  augroup my-glyph-palette
    autocmd! *
    autocmd FileType fern call glyph_palette#apply()
    autocmd FileType nerdtree,startify call glyph_palette#apply()
  augroup END
endif

if s:is_plugged("fern-git-status.vim")
  let g:fern_git_status#disable_ignored = 0
  let g:fern_git_status#disable_untracked = 0
  let g:fern_git_status#disable_submodules = 1
  let g:fern_git_status#disable_directories = 0
endif

if s:is_plugged("fzf.vim")
  nnoremap <Leader>fl :call fzf#vim#grep(
  	\ 'rg --ignore-file ~/.ripgrep_ignore --column --line-number --no-heading --hidden --smart-case .+',
  	\ 1,
  	\ fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:50%', '?'),
  	\ 0,)<CR>
  nnoremap <silent> <Leader>fb :Buffers<CR>
  nnoremap <silent> <Leader>ff :Files<CR>
  nnoremap <silent> <Leader>fl :Lines<CR>
endif

" fern
if s:is_plugged("fern.vim")
  let g:fern#default_hidden = 1
  let g:fern#disable_default_mappings = 1
  nnoremap <silent> <Leader>fo :Fern . -drawer -reveal=% -toggle<CR>
  function! s:init_fern() abort
    nmap <buffer> r <Plug>(fern-action-reload)
    nmap <buffer> R <Plug>(fern-action-remove)
    nmap <buffer> F <Plug>(fern-action-new-file)
    nmap <buffer> D <Plug>(fern-action-new-dir)
    nmap <buffer> z <Plug>(fern-action-zoom)
    nmap <buffer> l <Plug>(fern-action-open-or-expand)
    nmap <buffer> h <Plug>(fern-action-collapse)
    nmap <buffer> c <Plug>(fern-action-copy)
    nmap <buffer> m <Plug>(fern-action-move)
    nmap <buffer> <C-C> <Plug>(fern-action-cancel)
    nmap <buffer> <C-h> <Plug>(fern-action-leave)
    nmap <buffer> <CR> <Plug>(fern-action-enter)
    nmap <buffer> ? <Plug>(fern-action-help)
  endfunction
  augroup my-fern
    autocmd! *
    autocmd FileType fern call s:init_fern()
  augroup END
endif

" morhetz/gruvbox
if s:is_plugged("gruvbox")
  set background=dark
  try
    colorscheme gruvbox
  catch /^Vim\%((\a\+)\)\=:E185/
    colorscheme desert
  endtry
endif

if s:is_plugged("vim-fugitive")
  nnoremap <silent> <Leader>gl :Git log<CR>
  nnoremap <silent> <Leader>gd :Git diff<CR>
  nnoremap <silent> <Leader>gD :Git difftool<CR>
  nnoremap <silent> <Leader>gs :Git status<CR>
  nnoremap <silent> <Leader>gb :Git blame<CR>
endif

if s:is_plugged("vim-gitgutter")
  let g:gitgutter_map_keys = 0
  autocmd! BufWritePost * GitGutter
endif

if s:is_plugged("gv.vim")
  noremap <silent> <Leader>gl :GV!<CR>
endif

if s:is_plugged("open-browser-github.vim")
  nnoremap <silent> <Leader>ho :OpenGithubFile<CR>
  vnoremap <silent> <Leader>ho :'<,'>OpenGithubFile<CR>
endif

if s:is_plugged("bclose.vim")
  let g:no_plugin_maps = 1
  nnoremap <silent> qq :CloseTabOrBuffer<CR>
endif

if s:is_plugged("winresizer")
  let g:winresizer_start_key = "<S-w>"
endif

if s:is_plugged("vim-markdown")
  let g:vim_markdown_folding_disabled = 1
  let g:vim_markdown_new_list_item_indent = 0
  let g:vim_markdown_auto_insert_bullets = 1
  let g:vim_markdown_no_default_key_mappings = 1
endif

if s:is_plugged("incsearch.vim")
  map /  <Plug>(incsearch-forward)
  map ?  <Plug>(incsearch-backward)
  map g/ <Plug>(incsearch-stay)
endif

if s:is_plugged("vista.vim")
  nmap <silent> [LSP]v :<C-u>Vista<CR>
  let g:vista_executive_for = {
  \ 'go': 'coc',
  \ }
  let g:vista_fzf_preview = ['right:50%']
  let g:vista_sidebar_width = 30
  let g:vista_stay_on_open = 0
endif

if s:is_plugged("coc.nvim")
  " if node is not installed, suppress errors
  if executable("node")
    let g:coc_disable_uncaught_error = 1
  endif
  nnoremap [LSP] <Nop>
  map <Leader>l [LSP]
  nmap <silent> [LSP]d <plug>(coc-definition)
  nmap <silent> [LSP]t <Plug>(coc-type-definition)
  nmap <silent> [LSP]r <plug>(coc-references)
  nmap <silent> [LSP]R <plug>(coc-rename)
  nmap <silent> [LSP]f <plug>(coc-format)
  nmap <silent> [LSP]a <plug>(coc-codeaction)
  nmap <silent> [LSP]l <plug>(coc-codelens-action)
  nmap <silent> [LSP]h :call CocActionAsync('doHover')<CR>
  let g:coc_data_home	= expand(vim_cache . '/coc')
endif

" kubernetes
nnoremap [KUBERNETES] <Nop>
map <Leader>k [KUBERNETES]
noremap <silent> [KUBERNETES]a :'<,'>KubectlApply<CR>
noremap <silent> [KUBERNETES]D :'<,'>KubectlDelete<CR>
noremap <silent> [KUBERNETES]d :'<,'>KubectlDescribe<CR>
noremap <silent> [KUBERNETES]g :'<,'>KubectlGet<CR>

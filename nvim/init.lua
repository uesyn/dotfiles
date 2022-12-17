vim.opt.encoding = 'UTF-8'
vim.scriptencoding = 'utf-8'
vim.opt.backspace= {"indent", "eol", "start"}
vim.opt.display = {"lastline", "msgsep"}
vim.opt.hidden = true
vim.opt.hlsearch = true
vim.opt.linebreak = true
vim.opt.ruler = true
vim.opt.termguicolors = true
vim.opt.wildmenu = true
vim.opt.wildmode = "full"
vim.opt.inccommand = "split"
vim.opt.maxmempattern = 20000
vim.opt.updatetime = 100
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.showcmd = false
vim.opt.showmode = false
vim.opt.emoji = true
vim.opt.ambiwidth = "single"
vim.opt.fileformats = {"unix", "dos", "mac"}
vim.opt.foldcolumn = "0"
vim.opt.signcolumn = "yes"
vim.opt.laststatus = 2
vim.opt.showtabline = 2
vim.opt.breakindent = true
vim.opt.binary = true
vim.opt.eol = false

vim.g.netrw_fastbrowse = 0

-- set t_ut=
-- set t_8f=\<Esc>38;2;%lu;%lu;%lum
-- set t_8b=\<Esc>48;2;%lu;%lu;%lum

vim.api.nvim_create_augroup('my_quickfix', {})
vim.api.nvim_create_autocmd("FileType", {
  group = 'my_quickfix',
  pattern = 'qf',
  callback = function()
    vim.bo.buflisted = false
    vim.keymap.set('n', 'qq', ':clo<CR>', { buffer = true })
    vim.keymap.set('n', '<C-n>', '<Nop>', { buffer = true })
    vim.keymap.set('n', '<C-p>', '<Nop>', { buffer = true })
  end
})

vim.g.mapleader = " "
vim.keymap.set('n', '<Leader>', '<Nop>')
vim.keymap.set('n', 'ZZ', '<Nop>')
vim.keymap.set('n', 'ZQ', '<Nop>')
vim.keymap.set('n', 'q', '<Nop>')
vim.keymap.set('n', 'Q', '<Nop>')
vim.keymap.set('n', '<S-l>', '<C-w>l')
vim.keymap.set('n', '<S-h>', '<C-w>h')
vim.keymap.set('n', '<S-k>', '<C-w>k')
vim.keymap.set('n', '<S-j>', '<C-w>j')
vim.keymap.set('n', '<Leader><Space>', ':echo expand("%:p")<CR>')

-- keymap prefix
vim.keymap.set('n', '[LSP]', '<Nop>')
vim.keymap.set('n', '<Leader>l', '[LSP]', { remap = true })
vim.keymap.set('n', '[GIT]', '<Nop>')
vim.keymap.set('n', '<Leader>g', '[GIT]', { remap = true })
vim.keymap.set('n', '[BUFFER]', '<Nop>')
vim.keymap.set('n', '<Leader>g', '[BUFFER]', { remap = true })

vim.api.nvim_create_user_command('TrimSpaces', function() vim.api.nvim_command([[%s/\s\+$//e]]) end, { force = true })

-- packin
local packin = require('util.packin')

vim.g.packin_dir = vim.fn.expand("<sfile>:p:h") .. '/packin'
packin.load(
  {
    'prabirshrestha_vim-lsp',
    'mattn_vim-lsp-settings',
    'prabirshrestha_asyncomplete.vim',
    'prabirshrestha_asyncomplete-lsp.vim',
    'liuchengxu_vista.vim',
  },
  { setup = 'vim-lsp.vim', config = 'vim-lsp.vim' }
)

-- vfiler
packin.load(
  {
    'lambdalisue_fern.vim',
    'lambdalisue_fern-git-status.vim',
    'yuki-yano_fern-preview.vim',
  },
  { config = 'fern.vim', setup = 'fern.vim' }
)

-- statusline
packin.load(
  {
    'nvim-lualine_lualine.nvim'
  },
  { config = 'lualine.lua' }
)

-- tabbar
packin.load(
  {
    'nvim-tree_nvim-web-devicons',
    'romgrk_barbar.nvim',
  },
  { config = 'barbar.lua' }
)

-- fzf.vim
packin.load(
  {
    'junegunn_fzf',
    'junegunn_fzf.vim'
  },
  { config = 'fzf.vim' }
)

-- git
packin.load({ 'mhinz_vim-signify' })

-- colortheme
packin.load(
  { 'dracula_vim' },
  { config = 'dracula.vim', setup = 'dracula.vim' }
)

-- tweeks
packin.load(
  { 'ojroques_vim-oscyank' },
  { config = 'vim-oscyank.vim' }
)

packin.load(
  { 'simeji_winresizer' },
  { setup = 'winresizer.vim' }
)

packin.load(
  { 'antoinemadec_FixCursorHold.nvim' },
  { config = 'FixCursorHold.nvim.vim' }
)

packin.load(
  {
    'tyru_open-browser.vim',
    'tyru_open-browser-github.vim'
  },
  { config = 'open-browser.vim' }
)

packin.load({ 'dhruvasagar_vim-table-mode' })

-- filetype
packin.load({ 'hashivim_vim-terraform' })

packin.load(
  { 'plasticboy_vim-markdown' },
  { config = 'vim-markdown.vim' }
)

packin.load(
  { 'elzr_vim-json' },
  { config = 'vim-json.vim' }
)

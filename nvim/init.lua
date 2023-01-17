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

-- global options
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

-- keymap prefix
vim.keymap.set('n', '[LSP]', '<Nop>')
vim.keymap.set('n', '<Leader>l', '[LSP]', { remap = true })
vim.keymap.set('n', '[GIT]', '<Nop>')
vim.keymap.set('n', '<Leader>g', '[GIT]', { remap = true })
vim.keymap.set('n', '[BUFFER]', '<Nop>')
vim.keymap.set('n', '<Leader>g', '[BUFFER]', { remap = true })

vim.api.nvim_create_user_command('TrimSpaces', function() vim.api.nvim_command([[%s/\s\+$//e]]) end, { force = true })

-- lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme dracula]])
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    config = function()
      local lualine = require('lualine')

      -- Color table for highlights
      -- stylua: ignore
      local colors = {
        bg       = '#282a36',
        fg       = '#f8f8f2',
        yellow   = '#f1fa8c',
        cyan     = '#8be9fd',
        darkblue = '#6272a4',
        green    = '#50fa7b',
        orange   = '#ffb86c',
        purple   = '#bd93f9',
        pink     = '#ff79c6',
        blue     = '#8be9fd',
        red      = '#ff5555',
      }

      local conditions = {
        buffer_not_empty = function()
          return vim.fn.empty(vim.fn.expand('%:t')) ~= 1
        end,
        hide_in_width = function()
          return vim.fn.winwidth(0) > 80
        end,
        check_git_workspace = function()
          local filepath = vim.fn.expand('%:p:h')
          local gitdir = vim.fn.finddir('.git', filepath .. ';')
          return gitdir and #gitdir > 0 and #gitdir < #filepath
        end,
      }

      -- Config
      local config = {
        options = {
          -- Disable sections and component separators
          component_separators = '',
          section_separators = '',
          theme = {
            -- We are going to use lualine_c an lualine_x as left and
            -- right section. Both are highlighted by c theme .  So we
            -- are just setting default looks o statusline
            normal = { c = { fg = colors.fg, bg = colors.bg } },
            inactive = { c = { fg = colors.fg, bg = colors.bg } },
          },
          refresh = {
            statusline = 200,
          },
        },
        sections = {
          -- these are to remove the defaults
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          -- These will be filled later
          lualine_c = {},
          lualine_x = {},
        },
        inactive_sections = {
          -- these are to remove the defaults
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          lualine_c = {},
          lualine_x = {},
        },
        tabline = {},
        winbar = {
          lualine_a = {'diff'},
          lualine_b = {},
          lualine_c = {{'filename', path = 3}},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {}
        },
        inactive_winbar = {
          lualine_a = {'diff'},
          lualine_b = {},
          lualine_c = {{'filename', path = 3}},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {}
        },
      }

      -- Inserts a component in lualine_c at left section
      local function ins_left(component)
        table.insert(config.sections.lualine_c, component)
      end

      -- Inserts a component in lualine_x ot right section
      local function ins_right(component)
        table.insert(config.sections.lualine_x, component)
      end

      ins_left {
        function()
          return '▊'
        end,
        color = { fg = colors.blue }, -- Sets highlighting of component
        padding = { left = 0, right = 1 }, -- We don't need space before this
      }

      ins_left {
        -- mode component
        function()
          return ''
        end,
        color = function()
          -- auto change color according to neovims mode
          local mode_color = {
            n = colors.red,
            i = colors.green,
            v = colors.blue,
            [''] = colors.blue,
            V = colors.blue,
            c = colors.pink,
            no = colors.red,
            s = colors.orange,
            S = colors.orange,
            [''] = colors.orange,
            ic = colors.yellow,
            R = colors.purple,
            Rv = colors.purple,
            cv = colors.red,
            ce = colors.red,
            r = colors.cyan,
            rm = colors.cyan,
            ['r?'] = colors.cyan,
            ['!'] = colors.red,
            t = colors.red,
          }
          return { fg = mode_color[vim.fn.mode()] }
        end,
        padding = { right = 1 },
      }

      ins_left {
        -- filesize component
        'filesize',
        cond = conditions.buffer_not_empty,
      }

      ins_left {
        'filename',
        cond = conditions.buffer_not_empty,
        color = { fg = colors.pink, gui = 'bold' },
      }

      ins_left { 'location' }

      ins_left { 'progress', color = { fg = colors.fg, gui = 'bold' } }

      ins_left {
        'diagnostics',
        sources = { 'nvim_diagnostic', 'vim_lsp' },
        symbols = { error = ' ', warn = ' ', info = ' ' },
        diagnostics_color = {
          color_error = { fg = colors.red },
          color_warn = { fg = colors.yellow },
          color_info = { fg = colors.cyan },
        },
      }

      -- Insert mid section. You can make any number of sections in neovim :)
      -- for lualine it's any number greater then 2
      ins_left {
        function()
          return '%='
        end,
      }

      local progress_icons = {'⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'}

      local function get_progress_icon()
        local icon = progress_icons[progress_icons_index]
        progress_icons_index = tonumber(vim.fn.strftime('%s')) % #progress_icons + 1
        return icon
      end

      local function info_to_status(info)
        local msg = nil

        for server, messages in pairs(info) do
          local m = "[" .. server .. "]"

          if #messages > 0 then
            table.sort(messages)
            m = m .. " " .. table.concat(messages, ", ") .. " " .. get_progress_icon()
          end

          if msg == nil then
            msg = m
          else
            msg = msg .. " " .. m
          end
        end

        if msg == nil then
          return '[No Active Lsp]'
        end
        return msg
      end

      local function get_nvim_lsp_status()
        local info = {}
        local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
        local clients = vim.lsp.get_active_clients()

        for _, client in ipairs(clients) do
          if info[client.name] == nil then
            info[client.name] = {}
          end

          local filetypes = client.config.filetypes
          if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            for i, m in ipairs(require('lsp-status').messages()) do
              if m.title == nil then
                goto continue
              end

              table.insert(info[client.name], m.title)
              ::continue::
            end
          end
        end

        return info_to_status(info)
      end

      local function get_vim_lsp_status()
        local info = {}

        if vim.fn.exists('*lsp#get_progress') == 0 then
          return info_to_status(info)
        end

        local progresses = vim.fn['lsp#get_progress']()
        for i, p in ipairs(progresses) do
          if p == nil or p.server == nil then
            goto continue
          end

          local server = p.server
          if info[server] == nil then
            info[server] = {}
          end

          if p.title == nil then
            goto continue
          end

          table.insert(info[server], p.title)
          ::continue::
        end

        for i, server in ipairs(vim.fn['lsp#get_server_names']()) do
          local status = vim.fn['lsp#get_server_status'](server)

          if info[server] == nil then
            info[server] = {}
          end

          if status ~= 'running' then
            table.insert(info[server], status)
          end
        end

        return info_to_status(info)
      end

      ins_left {
        -- Lsp server name .
        function()
          if vim.g.use_nvim_lsp then
            return get_nvim_lsp_status()
          end
          return get_vim_lsp_status()
        end,
        -- icon = ' ',
        color = { fg = '#ffffff', gui = 'bold' },
      }

      -- Add components to right sections
      ins_right {
        'o:encoding', -- option component same as &encoding in viml
        fmt = string.upper, -- I'm not sure why it's upper case either ;)
        cond = conditions.hide_in_width,
        color = { fg = colors.green, gui = 'bold' },
      }

      ins_right {
        'fileformat',
        fmt = string.upper,
        icons_enabled = false, -- I think icons are cool but Eviline doesn't have them. sigh
        color = { fg = colors.green, gui = 'bold' },
      }

      ins_right {
        'branch',
        icon = '',
        color = { fg = colors.purple, gui = 'bold' },
      }

      ins_right {
        'diff',
        -- Is it me or the symbol for modified us really weird
        symbols = { added = ' ', modified = '柳 ', removed = ' ' },
        diff_color = {
          added = { fg = colors.green },
          modified = { fg = colors.orange },
          removed = { fg = colors.red },
        },
        cond = conditions.hide_in_width,
      }

      ins_right {
        function()
          return '▊'
        end,
        color = { fg = colors.blue },
        padding = { left = 1 },
      }

      -- Now don't forget to initialize lualine
      lualine.setup(config)
    end,
  },
  {
    "romgrk/barbar.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    lazy = false,
    config = function()
      vim.keymap.set('n', '<S-q>', '<Cmd>BufferClose<CR>')
      vim.keymap.set('n', '<C-n>', '<Cmd>BufferNext<CR>')
      vim.keymap.set('n', '<C-p>', '<Cmd>BufferPrevious<CR>')
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    keys = "<Leader>fo",
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.opt.termguicolors = true

      vim.keymap.set('n', '<Leader>fo', '<Cmd>NvimTreeToggle<CR>')

      -- OR setup with some options
      require("nvim-tree").setup({
        disable_netrw = false,
        hijack_cursor = false,
        hijack_netrw = true,
        sort_by = "case_sensitive",
        view = {
          adaptive_size = true,
          mappings = {
            custom_only = true,
            list = {
              { key = "u", action = "dir_up" },
              { key = "<CR>", action = "cd" },
              { key = "l", action = "edit" },
              { key = "h", action = "close_node" },
              { key = "p", action = "preview" },
              { key = "r", action = "refresh" },
              { key = "f", action = "create" },
              { key = "D", action = "remove" },
              { key = "R", action = "rename" },
              { key = "c", action = "copy" },
              { key = "x", action = "cut" },
            },
          },
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = false,
        },
      })
    end,
  },
  {
    "mhinz/vim-signify",
    lazy = false,
  },
  {
    "tyru/open-browser.vim",
    dependencies = {
      "tyru/open-browser-github.vim",
    },
    keys = {"<Leader>ho", {"<Leader>ho", mode = "v"}},
    config = function()
      vim.keymap.set('n', '<Leader>ho', '<Cmd>OpenGithubFile<CR>')
      vim.keymap.set('v', '<Leader>ho', "<Cmd>'<,'>OpenGithubFile<CR>")
    end,
  },
  {
    "simeji/winresizer",
    keys = "<S-w",
    init = function()
      vim.g.winresizer_start_key = "<S-w>"
    end,
  },
  -- filetype
  {
    "elzr/vim-json",
    ft = "json",
    setup = function()
      vim.g.vim_json_syntax_conceal = 0
    end,
  },
  {
    "hashivim/vim-terraform",
    ft = "terraform",
  },
  {
    "preservim/vim-markdown",
    ft = "markdown",
    config = function()
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_new_list_item_indent = 0
      vim.g.vim_markdown_auto_insert_bullets = 1
      vim.g.vim_markdown_no_default_key_mappings = 1
    end,
  },
  {
    "junegunn/fzf",
    dependencies = {
      "junegunn/fzf.vim",
    },
    keys = {"<Leader>fs", "<Leader>ff"},
    config = function()
      vim.keymap.set('n', '<Leader>fs', ":Rg<space>")
      vim.keymap.set('n', '<Leader>ff', "<Cmd>FZF<CR>")
    end,
  },
  {
    "ojroques/vim-oscyank",
    lazy = false,
    config = function()
      vim.keymap.set('v', '<Leader>y', "<Cmd>OSCYank<CR>")
      vim.g.oscyank_term = 'default'
      vim.g.oscyank_max_length = 1000000
      vim.cmd[[autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif]]
    end,
  },
  {
    'dhruvasagar/vim-table-mode',
    event = "VeryLazy",
  },
  {
    'prabirshrestha/vim-lsp',
    dependencies = {
      'prabirshrestha/asyncomplete.vim',
      'prabirshrestha/asyncomplete-lsp.vim',
      'mattn/vim-lsp-settings',
    },
    init = function()
      vim.g.lsp_work_done_progress_enabled = 1
      vim.g.lsp_document_code_action_signs_enabled = 0
      vim.g.lsp_diagnostics_echo_cursor = 1
      vim.g.lsp_diagnostics_echo_delay = 50
      vim.g.lsp_diagnostics_highlights_enabled = 0
      vim.g.lsp_diagnostics_highlights_delay = 50
      vim.g.lsp_diagnostics_highlights_insert_mode_enabled = 0
      vim.g.lsp_diagnostics_signs_enabled = 1
      vim.g.lsp_diagnostics_signs_delay = 50
      vim.g.lsp_diagnostics_signs_insert_mode_enabled = 0
      vim.g.lsp_diagnostics_virtual_text_enabled = 0
      vim.g.lsp_diagnostics_virtual_text_delay = 50
      vim.g.lsp_diagnostics_float_cursor = 0
      vim.g.lsp_diagnostics_float_delay = 1000
      vim.g.lsp_completion_documentation_delay = 40
      vim.g.lsp_document_highlight_delay = 50
      vim.g.lsp_document_code_action_signs_delay = 100
      vim.g.lsp_fold_enabled = 0
      vim.g.lsp_text_edit_enabled = 0
      vim.g.lsp_settings_filetype_typescript = {'typescript-language-server', 'deno'}
      vim.g.lsp_settings_filetype_javascript = {'typescript-language-server', 'deno'}
    end,
    config = function()
      vim.keymap.set('n', '[LSP]D', "<plug>(lsp-declaration)")
      vim.keymap.set('n', '[LSP]d', "<plug>(lsp-definition)")
      vim.keymap.set('n', '[LSP]h', "<plug>(lsp-hover)")
      vim.keymap.set('n', '[LSP]t', "<plug>(lsp-type-definition)")
      vim.keymap.set('n', '[LSP]r', "<plug>(lsp-references)")
      vim.keymap.set('n', '[LSP]R', "<plug>(lsp-rename)")
      vim.keymap.set('n', '[LSP]a', "<plug>(lsp-code-action)")
      vim.keymap.set('n', '[LSP]f', "<plug>(lsp-document-format)")
      vim.keymap.set('n', '[LSP]q', "<plug>(lsp-document-diagnostics)")
      vim.keymap.set('n', '[LSP]i', "<Cmd>LspCodeActionSync source.organizeImports<CR>")
      vim.opt.signcolumn = "yes"
      vim.opt.omnifunc = "lsp#complete"
    end,
  },
}
require("lazy").setup(plugins)

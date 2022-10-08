-- fork from: https://github.com/nvim-lualine/lualine.nvim/blob/master/examples/evil_lualine.lua
-- Eviline config for lualine
-- Author: shadmansaleh
-- Credit: glepnir

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
      [''] = colors.blue,
      V = colors.blue,
      c = colors.pink,
      no = colors.red,
      s = colors.orange,
      S = colors.orange,
      [''] = colors.orange,
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

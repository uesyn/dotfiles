-- Custom statusline: mode block, git branch (from gitsigns), filetype with
-- icon, encoding and fileformat. Kept in Lua rather than a plugin because the
-- layout is small and specific.

-- Only the colors used below, taken from the dracula palette.
local colors = {
  fg = "#F8F8F2",
  bg = "#44475a",
  pink = "#FF79C6",
  orange = "#FFB86C",
}

vim.api.nvim_set_hl(0, "StatusMode", { fg = colors.fg, bg = colors.pink })
vim.api.nvim_set_hl(0, "StatusModeBrackets", { fg = colors.pink })
vim.api.nvim_set_hl(0, "StatusGit", { fg = colors.orange, bg = colors.bg })

-- Powerline separators; they match the rounded window borders.
local separator = { left = vim.fn.nr2char(0xe0b6), right = vim.fn.nr2char(0xe0b4) }

local mode_names = {
  n = "NORMAL",
  i = "INSERT",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  c = "COMMAND",
  R = "REPLACE",
  t = "TERMINAL",
  s = "SELECT",
}

local function mode_block()
  local mode = mode_names[vim.api.nvim_get_mode().mode:sub(1, 1)] or "UNKNOWN"
  return table.concat({
    "%#StatusModeBrackets#",
    separator.left,
    "%*%#StatusMode#",
    mode,
    "%*%#StatusModeBrackets#",
    separator.right,
    "%*",
  })
end

local function git_branch()
  local branch = vim.b.gitsigns_head
  if not branch or branch == "" then
    return nil
  end
  return "%#StatusGit#" .. branch .. "%*"
end

local function filetype()
  local filetype = vim.bo.filetype
  if filetype == "" then
    return nil
  end

  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return filetype
  end

  local icon, hl = devicons.get_icon_by_filetype(filetype)
  if not icon then
    return filetype
  end
  return "%#" .. hl .. "#" .. icon .. "%* " .. filetype
end

local function render()
  local parts = { mode_block() }

  local branch = git_branch()
  if branch then
    table.insert(parts, " " .. branch)
  end

  table.insert(parts, "%=")

  local ft = filetype()
  if ft then
    table.insert(parts, ft .. " ")
  end

  table.insert(parts, vim.bo.fileencoding .. " ")
  table.insert(parts, vim.bo.fileformat .. " ")
  table.insert(parts, "%3p%% ")
  return table.concat(parts)
end

-- `v:lua` can only call globals: this is the single global the config exposes.
-- (ftplugin/dump.lua falls back to it while keeping its own window override.)
_G.statusline = render
vim.o.statusline = "%!v:lua.statusline()"

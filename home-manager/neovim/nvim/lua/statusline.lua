local colors = {
   bg = "#44475a",
   fg = "#F8F8F2",
   red = "#FF5555",
   orange = "#FFB86C",
   yellow = "#F1FA8C",
   green = "#50fa7b",
   purple = "#BD93F9",
   cyan = "#8BE9FD",
   pink = "#FF79C6",
   bright_red = "#FF6E6E",
   bright_green = "#69FF94",
   bright_yellow = "#FFFFA5",
   bright_blue = "#D6ACFF",
   bright_magenta = "#FF92DF",
   bright_cyan = "#A4FFFF",
   bright_white = "#FFFFFF",
   white = "#ABB2BF",
   black = "#191A21",
}

vim.api.nvim_set_hl(0, "StatusMode", { fg = colors.fg, bg = colors.pink })
vim.api.nvim_set_hl(0, "StatusModeBrackets", { fg = colors.pink })
vim.api.nvim_set_hl(0, "StatusGit", { fg = colors.orange, bg = colors.bg })

local function get_mode()
  local m = vim.api.nvim_get_mode().mode

  local map = {
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

  local key = m:sub(1, 1)
  local mode = map[key] or "UNKNOWN"

  result = "%#StatusModeBrackets#" .. "" .. "%*"
  result = result .. "%#StatusMode#" .. mode .. "%*"
  result = result .. "%#StatusModeBrackets#" .. "" .. "%*"
  return result
end

local function get_git_branch()
  -- depending on gitsigns
  local branch = vim.b.gitsigns_head
  if not branch or branch == "" then
    return ""
  end
  return "%#StatusGit#" .. branch .. "%*"
end

local function get_filetype()
  local filetype = vim.bo.filetype
  if filetype == "" then
    return ""
  end

  local ok, icons = pcall(require, "nvim-web-devicons")
  if not ok then
    return filetype
  end
  local icon, hl = icons.get_icon_by_filetype(filetype)
  local result = icon and "%#" .. hl .. "#" .. icon .. "%*" .. " " .. filetype or filetype
  return result
end

function _G.statusline()
  local line = ""

  local mode = get_mode()
  line = line .. mode

  local branch = get_git_branch()
  if branch ~= "" then
    line = line .. " " .. branch
  end

  line = line .. "%="

  local filetype = get_filetype()
  if filetype ~= "" then
    line = line .. filetype .. " "
  end

  line = line .. vim.bo.fileencoding .. " "
  line = line .. vim.bo.fileformat .. " "
  line = line .. "%3p%%" .. " "
  return line
end

vim.opt.laststatus = 3
vim.o.statusline = "%!v:lua.statusline()"

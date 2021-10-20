local wezterm = require 'wezterm'

return {
  colors = {
    foreground = "#ebdbb2",
    background = "#282828",
    cursor_bg = "#e6d4a3",
    cursor_border = "#e6d4a3",
    cursor_fg = "#1e1e1e",
    selection_bg = "#e6d4a3",
    selection_fg = "#534a42",
    ansi = {"#1e1e1e","#be0f17","#868715","#cc881a","#377375","#a04b73","#578e57","#978771"},
    brights = {"#7f7061","#f73028","#aab01e","#f7b125","#719586","#c77089","#7db669","#e6d4a3"},
  },
  font = wezterm.font_with_fallback {
    'JetBrains Mono NL',
    'JetBrains Mono',
  },
  font_size = 22,
  hide_tab_bar_if_only_one_tab = true,
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },
}
local wezterm = require 'wezterm'

return {
  colors = {
    ansi = {
        '#21222c',
        '#ff5555',
        '#50fa7b',
        '#f1fa8c',
        '#bd93f9',
        '#ff79c6',
        '#8be9fd',
        '#f8f8f2',
    },
    background = '#282a36',
    brights = {
        '#6272a4',
        '#ff6e6e',
        '#69ff94',
        '#ffffa5',
        '#d6acff',
        '#ff92df',
        '#a4ffff',
        '#ffffff',
    },
    compose_cursor = '#ffb86c',
    cursor_bg = '#f8f8f2',
    cursor_border = '#f8f8f2',
    cursor_fg = '#282a36',
    foreground = '#f8f8f2',
    scrollbar_thumb = '#44475a',
    selection_bg = 'rgba(26.666668% 27.843138% 35.294117% 50%)',
    selection_fg = 'rgba(0% 0% 0% 0%)',
    split = '#6272a4',
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
  front_end = "WebGpu", -- https://github.com/wez/wezterm/issues/2756
}
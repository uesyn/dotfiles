let g:lsp_status_icons = ['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷']
let g:lsp_status_icons_index = 0
function! LspStatusVimLSP() abort
  if ! exists("*lsp#get_progress")
    return ""
  endif

  let progresses = lsp#get_progress()
  let messages = ""
  for progress in progresses
    let m = ""
    if len(progress['server']) > 0
      let m = m .. "[" .. progress['server'] .. "]"
    endif
    if len(progress['title']) > 0
      let m = m .. " " .. progress['title']
      if len(progress['message']) > 0
        let m = m .. ":" .. progress['message']
      endif
    endif
    if len(m) > 0
      if len(messages) == 0
        let messages = m
      else
        let messages = messages .. "," .. m
      endif
    endif
  endfor

  if len(messages) == 0
    return ""
  endif

  let g:lsp_status_icons_index = (g:lsp_status_icons_index + 1) % len(g:lsp_status_icons)
  let icon = g:lsp_status_icons[g:lsp_status_icons_index]
  return icon .. " " .. messages
endfunction

if !exists("g:lightline")
  let g:lightline = {}
endif
let g:lightline['colorscheme'] = 'dracula'
let g:lightline['active'] = {'left': [['mode'], ['filename'], ['lspstatus']], 'right': [['fileformat', 'fileencoding', 'filetype', 'percent']]}
let g:lightline['component_function'] = {'lspstatus': 'LspStatusVimLSP'}
" based on https://github.com/shinchu/lightline-gruvbox.vim
" let g:lightline['colorscheme'] = 'gruvbox'
" let g:lightline#colorscheme#gruvbox#palette = {'inactive': {'right': [['#7c6f64', '#504945', 243, 239], ['#7c6f64', '#504945', 243, 239]], 'middle': [['#7c6f64', '#504945', 243, 239]], 'left': [['#7c6f64', '#504945', 243, 239], ['#7c6f64', '#504945', 243, 239]]}, 'replace': {'left': [['#282828', '#fb4934', 235, 167], ['#fbf1c7', '#665c54', 245, 241]]}, 'normal': {'right': [['#282828', '#7c6f64', 235, 243], ['#282828', '#7c6f64', 235, 243]], 'middle': [['#7c6f64', '#3c3836', 243, 237]], 'warning': [['#282828', '#fe8019', 235, 208]], 'left': [['#282828', '#b8bb26', 235, 142], ['#fbf1c7', '#665c54', 245, 241]], 'error': [['#282828', '#fb4934', 235, 167]]}, 'tabline': {'right': [['#7c6f64', '#3c3836', 243, 237], ['#282828', '#7c6f64', 235, 243]], 'middle': [['#282828', '#7c6f64', 235, 243]], 'left': [['#7c6f64', '#3c3836', 243, 237]], 'tabsel': [['#fbf1c7', '#282828', 245, 235]]}, 'visual': {'left': [['#282828', '#fe8019', 235, 208], ['#fbf1c7', '#665c54', 245, 241]]}, 'insert': {'left': [['#282828', '#83a598', 235, 109], ['#fbf1c7', '#665c54', 245, 241]]}}

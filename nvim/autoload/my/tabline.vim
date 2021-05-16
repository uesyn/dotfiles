function! s:tab_label_from_buffer(bufnum)
  let label = a:bufnum is bufnr() ? '%#TabLineSel#' : '%#TabLine#'
  if getbufvar(a:bufnum, "&modified")
    let label .= "[+]"
  endif

  let shorten_path = pathshorten(bufname(a:bufnum))
  let bufname = empty(shorten_path) ? '[No Name]' : shorten_path

  let label .= bufname . '%#TabLineFill#%T'
  return label
endfunction

function! my#tabline#make_tab_line()
  let s = ""
  let tabnum = tabpagenr('$')
  if tabnum > 1
    let s .= '%#TabLineSel#' . '[CODE JUMP ' . (tabnum - 1) . ']' . '%#TabLineFill#%T '
  endif

  let valid_buffer_list = my#buffer#valid_buffer_list()
  let labels = map(valid_buffer_list, 's:tab_label_from_buffer(v:val)')
  return s . ' ' . join(labels, " | ")
endfunction

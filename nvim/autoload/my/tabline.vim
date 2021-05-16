function! s:tab_label(n)
  let label = a:n is bufnr() ? '%#TabLineSel#' : '%#TabLine#'
  if getbufvar(a:n, "&modified")
    let label .= "[+]"
  endif

  let shorten_path = pathshorten(bufname(a:n))
  let bufname = empty(shorten_path) ? '**empty buffer**' : shorten_path

  let label .= bufname . '%#TabLineFill#%T'
  return label
endfunction

function! my#tabline#make_tab_line()
  let s = ""
  let tabnum = tabpagenr('$')
  if tabnum > 1
    let s .= '%#TabLineSel#' . '[CODE JUMP ' . (tabnum - 1) . ']' . '%#TabLineFill#%T '
  endif

  let buffers = filter(range(1, bufnr('$')), 'buflisted(v:val)')
  let labels = map(buffers, 's:tab_label(v:val)')
  return s . ' ' . join(labels, " | ")
endfunction

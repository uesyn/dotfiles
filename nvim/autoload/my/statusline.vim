function! my#statusline#set_status_line()
  let fpath = fnamemodify(bufname(bufnr()), ":p")
  if !filereadable(fpath)
    let &l:statusline = " "
    return
  endif
  let &l:statusline = "%r%m\ %F\ %=%{coc#status()}%y"
  return
endfunction

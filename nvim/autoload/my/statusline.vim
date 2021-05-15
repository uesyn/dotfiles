function! my#statusline#make_status_line()
  let line = "%r%m\ %F\ %=%{coc#status()}%y"
  return line
endfunction

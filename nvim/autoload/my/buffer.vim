function! my#buffer#next_buffer()
  if getbufvar(bufnr(), "&filetype") is "fern"
    return
  endif
  bnext
endfunction

function! my#buffer#previous_buffer()
  if getbufvar(bufnr(), "&filetype") is "fern"
    return
  endif
  bprevious
endfunction

if !exists("g:my_buffer_invalid_buffer_filetypes")
  let g:my_buffer_invalid_buffer_filetypes = ["qf", "fern", "netrw", "help"]
endif

function! s:valid_buffer_filetype(filetype)
  for ftype in g:my_buffer_invalid_buffer_filetypes
    if a:filetype ==# ftype
      return 0
    endif
  endfor
  return 1
endfunction

function! my#buffer#valid_buffer(bufnum)
  let ftype = getbufvar(a:bufnum, "&filetype")
  return s:valid_buffer_filetype(ftype)
endfunction

function! my#buffer#valid_buffer_list()
  let valid_buffers = []
  let buffer_nums = filter(range(1, bufnr('$')), 'buflisted(v:val)')

  for bufnum in buffer_nums
    if my#buffer#valid_buffer(bufnum)
      call add(valid_buffers, bufnum)
    endif
  endfor

  return valid_buffers
endfunction

" return valid next buffer.
" if return -1, valid buffer is not found.
function! my#buffer#next_valid_buffer(reverse)
  let valid_buffer_list = my#buffer#valid_buffer_list()

  if len(valid_buffer_list) is 0
    return -1
  endif

  if a:reverse is 1
    call reverse(valid_buffer_list)
  endif

  let next_valid_index = 0
  for bufnum in valid_buffer_list
    let next_valid_index = (next_valid_index + 1) % len(valid_buffer_list)
    if bufnum is bufnr()
      " if current buffer is next valid index, return -1
      if valid_buffer_list[next_valid_index] is bufnr()
        return -1
      endif
      return valid_buffer_list[next_valid_index]
    endif
  endfor

  " if valid buffer is not found, return first valid buffer.
  return valid_buffer_list[0]
endfunction

function! my#buffer#move_next_valid_buffer(reverse)
  " not to move next buffer if in invalid buffer
  if !my#buffer#valid_buffer(bufnr())
    return
  endif

  let next_buffer = my#buffer#next_valid_buffer(a:reverse)
  if next_buffer is -1
    return
  endif
  execute "buffer " . next_buffer
endfunction

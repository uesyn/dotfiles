if !exists("g:my_buffer_invalid_buffer_filetypes")
  let g:my_buffer_invalid_buffer_filetypes = ["qf", "fern", "netrw"]
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

  call sort(valid_buffers, 'n')

  return valid_buffers
endfunction

function! my#buffer#move_next_valid_buffer(reverse)
  " not to move next buffer if in invalid buffer
  if !my#buffer#valid_buffer(bufnr())
    return
  endif

  let valid_buffer_list = my#buffer#valid_buffer_list()
  if a:reverse is 1
    call reverse(valid_buffer_list)
  endif

  let next_valid_index = 0
  for bufnum in valid_buffer_list
    let next_valid_index = (next_valid_index + 1) % len(valid_buffer_list)
    if bufnum is bufnr()
      while !my#buffer#valid_buffer(valid_buffer_list[next_valid_index])
        let next_valid_index = (next_valid_index + 1) % len(valid_buffer_list)
      endwhile
      break
    endif
  endfor

  execute "buffer " . valid_buffer_list[next_valid_index]
endfunction

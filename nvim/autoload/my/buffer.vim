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

function! my#buffer#next_buffer(reverse)
  " not to move next buffer if in invalid buffer
  if !my#buffer#valid_buffer(bufnr())
    return
  endif

  let idx = 0
  let valid_buffer_list = my#buffer#valid_buffer_list()
  if a:reverse is 1
    call reverse(valid_buffer_list)
  endif

  for bufnum in valid_buffer_list
    if bufnum is bufnr()
      let idx = idx + 1
      break
    endif
    let idx = idx + 1
  endfor

  let idx = idx % len(valid_buffer_list)

  while ! my#buffer#valid_buffer(valid_buffer_list[idx])
    let idx = (idx + 1) % len(valid_buffer_list)
  endwhile

  execute "buffer " . valid_buffer_list[idx]
endfunction

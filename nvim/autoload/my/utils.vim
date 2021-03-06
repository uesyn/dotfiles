function! my#utils#close_tab_or_buffer()
  let current_tab_page = tabpagenr()
  let current_buffer = bufnr()

  " if more than or equal 2 tabs, close current tab.
  let tabnum = tabpagenr('$')
  if tabnum > 1
    execute "tabclose " . current_tab_page
    return
  endif

  " if no tabs, close current buffer, and move to valid previous buffer.
  let previous_buffer = my#buffer#next_valid_buffer(1)
  if previous_buffer is -1
    " if previous buffer is not found, close window.
    quit
    return
  endif

  execute "buffer " . previous_buffer
  execute "bwipeout" . current_buffer
endfunction

function! my#utils#plug_load_status()
  if filereadable(expand('~/.config/nvim/plug_lock.vim'))
    source ~/.config/nvim/plug_lock.vim
  endif
endfunction

function! my#utils#plug_save_status()
  PlugSnapshot ~/.config/nvim/plug_lock.vim
endfunction

function! my#utils#close_tab_or_buffer()
  let current_tab_page = tabpagenr()
  let current_buffer = bufnr()

  " if vim has more than or equal 2 tabs, close current tab
  let tabnum = tabpagenr('$')
  if tabnum > 1
    execute "tabclose " . current_tab_page
    return
  endif

  " if no tabs, close current buffer.
  " and move to valid previous buffer.
  try
    Bclose
  catch
  endtry
endfunction

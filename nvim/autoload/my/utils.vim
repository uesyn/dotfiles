function! my#utils#plug_load_status()
  if filereadable(expand('~/.config/nvim/plug_lock.vim'))
    source ~/.config/nvim/plug_lock.vim
  endif
endfunction

function! my#utils#plug_save_status()
  PlugSnapshot ~/.config/nvim/plug_lock.vim
endfunction

function! my#utils#close_tab_or_buffer()
  try
    tabclose
  catch
    Bclose
  endtry
endfunction

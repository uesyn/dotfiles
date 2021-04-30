command! -range=% SyncClipboardWithSelectedArea <line1>,<line2>call my#utils#syncclipboard_with_selected()

command! PlugSaveStatus call my#utils#plug_save_status()
command! PlugLoadStatus call my#utils#plug_load_status()

command! TrimSpaces call execute('%s/\s\+$//e')

command! CloseTabOrBuffer call my#utils#close_tab_or_buffer()

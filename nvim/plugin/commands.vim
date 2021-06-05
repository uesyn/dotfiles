command! TrimSpaces call execute('%s/\s\+$//e')

command! CloseTabOrBuffer call my#utils#close_tab_or_buffer()
command! NextBuffer call my#buffer#move_next_valid_buffer(0)
command! PreviousBuffer call my#buffer#move_next_valid_buffer(1)

" kubernetes
command! -range=% KubectlApply <line1>,<line2>call my#kubernetes#kubectl_apply()
command! -range=% KubectlDelete <line1>,<line2>call my#kubernetes#kubectl_delete()
command! -range=% KubectlDescribe <line1>,<line2>call my#kubernetes#kubectl_describe()
command! -range=% KubectlGet <line1>,<line2>call my#kubernetes#kubectl_get()

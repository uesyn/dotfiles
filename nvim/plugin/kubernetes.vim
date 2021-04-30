command! -range=% KubectlApply <line1>,<line2>call my#kubernetes#kubectl_apply()
command! -range=% KubectlDelete <line1>,<line2>call my#kubernetes#kubectl_delete()
command! -range=% KubectlDescribe <line1>,<line2>call my#kubernetes#kubectl_describe()
command! -range=% KubectlGet <line1>,<line2>call my#kubernetes#kubectl_get()

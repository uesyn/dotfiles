function! my#kubernetes#kubectl_apply() range
  echo "[kubectl apply]"
  let selected_lines = getline(a:firstline, a:lastline)
  let diff_result = system('kubectl diff -f-', selected_lines)
  if len(diff_result) == 0
    echo "No difference"
    return
  endif
  echo diff_result
  let choice = confirm("Apply these changes?", "yes \nno \n")
  if choice != 1
    echo "canceled"
    return
  endif
  echo system('kubectl apply -f-', selected_lines)
  redraw
endfunction

function! my#kubernetes#kubectl_delete() range
  echo "[kubectl delete]"
  let selected_lines = getline(a:firstline, a:lastline)
  let get_result = system('kubectl get -o name --ignore-not-found=true -f-', selected_lines)
  if len(get_result) == 0
    echo " * Target not found"
    return
  endif
  echo "Delete targets"
  for item in split(get_result)
    echo " * " . item
  endfor
  let choice = confirm("This is message. Which is your selection ?", "yes \nno \n")
  if choice == 1
    echo system('kubectl delete -f-', selected_lines)
  endif
  redraw
endfunction

function! my#kubernetes#kubectl_describe() range
  echo "[kubectl describe]"
  echo system('kubectl describe -f-', getline(a:firstline, a:lastline))
  redraw
endfunction

function! my#kubernetes#kubectl_get() range
  echo "[kubectl get]"
  echo system('kubectl get -o yaml -f-', getline(a:firstline, a:lastline))
  redraw
endfunction

command! -range=% KubectlGet <line1>,<line2>call my#kubernetes#kubectl_get()
command! -range=% KubectlApply <line1>,<line2>call my#kubernetes#kubectl_apply()
command! -range=% KubectlDelete <line1>,<line2>call my#kubernetes#kubectl_delete()
command! -range=% KubectlDescribe <line1>,<line2>call my#kubernetes#kubectl_describe()

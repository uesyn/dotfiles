if exists("g:packin_loaded")
  finish
endif
let g:packin_loaded = 1

" To load this file
function! packin#begin() abort
  if !exists("g:packin_dir")
    let g:packin_dir = expand("~/.config/nvim/packin")
  endif

  let s:packin_plugin_config_dir = g:packin_dir .. "/config"
  let s:packin_plugin_setup_dir = g:packin_dir .. "/setup"
  
  let s:packin_plugin_loaded = {}
  let s:packin_plugin_registered = {}
  let s:packin_plugin_dependency_map = {}
  let s:packin_plugin_opt_dirs = []
endfunction

function! packin#check_plugin_installed(name) abort
  return s:check_plugin_installed(a:name)
endfunction

function! s:check_plugin_installed(name) abort
  if len(s:packin_plugin_opt_dirs) == 0
    for opt_dir_pattern in map(split(&packpath, ','), 'v:val .. "/pack/*/opt"')
      for opt_dir in split(glob(opt_dir_pattern), "\n")
        let s:packin_plugin_opt_dirs = add(s:packin_plugin_opt_dirs, opt_dir)
      endfor
    endfor
  endif

  for opt_dir in s:packin_plugin_opt_dirs
    if isdirectory(opt_dir .. "/" .. a:name)
      return v:true
    endif
  endfor
  return v:false
endfunction

function! Packin(plugin) abort
  if !has_key(a:plugin, 'name')
    echoerr "must set 'name' parameter"
    return 1
  endif

  let name = a:plugin['name']
  call s:regist_plugin(name, a:plugin)
endfunction

function! s:to_list(arg) abort
  if type(a:arg) == 3
    return a:arg
  endif
  return [a:arg]
endfunction

function! s:is_registered(name) abort
  return has_key(s:packin_plugin_registered, a:name)
endfunction

function! s:regist_plugin(name, plugin) abort
  let s:packin_plugin_registered[a:name] = a:plugin
endfunction

function! s:get_registered_plugin(name) abort
  if !s:is_registered(a:name)
    echoerr "Plugin is not registered: " .. a:name
    return
  endif
  return s:packin_plugin_registered[a:name]
endfunction

function! s:get_registered_plugin_names() abort
  return keys(s:packin_plugin_registered)
endfunction

function s:resolve_plugin_dependencies(name) abort
  if !s:is_registered(a:name)
    echoerr "Plugin is not registered: " .. a:name
    return []
  endif
  let plugin = s:get_registered_plugin(a:name)

  if !has_key(plugin, 'after')
    return []
  endif

  let merged = []
  let visited = {}

  for dependency in s:to_list(plugin['after'])
    for dd in s:resolve_plugin_dependencies(dependency) + [dependency]
      if has_key(visited, dd)
	continue
      endif
      let merged = add(merged, dd)
      let visited[dd] = 1
    endfor
  endfor

  return merged
endfunction

function! s:load_plugin(name) abort
  if s:is_loaded(a:name)
    return
  endif

  let plugin = s:get_registered_plugin(a:name)

  let dependencies = s:resolve_plugin_dependencies(plugin["name"])
  for dependency in dependencies
    call s:load_plugin(dependency)
  endfor

  if has_key(plugin, 'setup')
    let setup_file = s:packin_plugin_setup_dir .. "/" .. plugin["setup"]
    execute "source" setup_file
  endif

  execute "packadd" plugin["name"]

  if has_key(plugin, 'config')
    let config_file = s:packin_plugin_config_dir .. "/" .. plugin["config"]
    execute "source" config_file
  endif

  call s:mark_as_loaded(plugin["name"])
endfunction

function! s:mark_as_loaded(name) abort
  let s:packin_plugin_loaded[a:name] = 1
endfunction

function! s:is_loaded(name) abort
  return has_key(s:packin_plugin_loaded, a:name)
endfunction

function! packin#is_loaded(name) abort
  return s:is_loaded(a:name)
endfunction

function! packin#end() abort
  for name in s:get_registered_plugin_names()
    call s:load_plugin(name)
  endfor
endfunction

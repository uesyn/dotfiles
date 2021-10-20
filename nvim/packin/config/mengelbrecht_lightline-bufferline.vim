if !exists("g:lightline")
  let g:lightline = {}
endif

let g:lightline['tabline'] = {'left': [['buffers']],'right': [['close']]}
let g:lightline['component_expand'] = {'buffers': 'lightline#bufferline#buffers'}
let g:lightline['component_type'] = {'buffers': 'tabsel'}

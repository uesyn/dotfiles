autocmd BufRead,BufNewFile *.rego set filetype=rego

autocmd FileType rego setlocal commentstring=#\ %s
autocmd FileType rego setlocal comments=b:#,fb:-
autocmd FileType repo setlocal expandtab shiftwidth=2 softtabstop=2

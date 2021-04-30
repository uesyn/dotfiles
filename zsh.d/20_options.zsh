setopt hist_ignore_dups
setopt share_history
setopt automenu
zstyle ':completion:*:default' menu select=1
setopt auto_pushd
setopt pushd_ignore_dups
setopt complete_in_word
setopt list_packed
setopt nolistbeep
setopt transient_rprompt

bindkey -e
bindkey "^[[Z" reverse-menu-complete

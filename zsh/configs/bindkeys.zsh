bindkey -e
bindkey "^[[Z" reverse-menu-complete
bindkey "ƒ" forward-word
bindkey "∫" backward-word

[[ -x "$(command -v fzf)" ]] && bindkey "^R" user-fuzzy-history

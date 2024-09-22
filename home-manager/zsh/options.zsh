setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt share_history
setopt auto_menu
zstyle ':completion:*:default' menu select=1
setopt auto_pushd
setopt pushd_ignore_dups
setopt complete_in_word
setopt list_packed
setopt nolistbeep
setopt transient_rprompt
setopt hist_ignore_space
setopt magic_equal_subst
setopt always_last_prompt

# zsh
export WORDCHARS="?!"
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=1000000000
export SAVEHIST=1000000000

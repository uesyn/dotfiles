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
setopt hist_ignore_space

# zsh
export WORDCHARS="?!"
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=1000000000
export SAVEHIST=1000000000

function zshaddhistory() {
  emulate -L zsh
  # not to save github token
  if [[ ${1%%$'\n'} =~ (.*gh[pousr]_.*) ]]; then
    return 1
  fi
}

zmodload zsh/complete
zmodload zsh/zle

# kubernetes
alias k='kubectl'
alias ks='kubectl -n kube-system'
alias kx='kubectx'
alias kn='kubens'

case $OSTYPE in
  linux*)
    alias ll='ls --color -l'
    alias ls='ls --color'
    ;;
  darwin*)
    if [[ -x "$(command -v gls)" ]]; then
      alias ll='gls --color -l'
      alias ls='gls --color'
    fi
    if [[ -x "$(command -v gmake)" ]]; then
      alias make="gmake"
    fi
    ;;
esac

function tm() {
  [[ -n ${TMUX} ]] && return
  tmux new-session -ADs main
}

function z() {
  [[ -n ${ZELLIJ_SESSION_NAME} ]] && return
  zellij attach -c
}

# nvim
[[ -x "$(command -v nvim)" ]] && alias vim="nvim"

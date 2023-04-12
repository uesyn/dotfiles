# kubernetes
alias k='kubectl'
alias ks='kubectl -n kube-system'
alias kx='kubectx'
alias kn='kubens'

alias d="devbox"

case $OSTYPE in
  linux*)
    alias ll='\ls --color -l'
    alias ls='\ls --color'
    ;;
  darwin*)
    if [[ -d "${OPT_DIR}/coreutils/bin" ]]; then
      alias ll='\ls --color -l'
      alias ls='\ls --color'
    elif [[ -x "$(command -v gls)" ]]; then
      alias ll='\gls --color -l'
      alias ls='\gls --color'
    fi
    if [[ -x "$(command -v gmake)" ]]; then
      alias make="gmake"
    fi
    ;;
esac

function z() {
  if [[ -x "$(command -v zellij)" ]]; then
    [[ -n ${ZELLIJ_SESSION_NAME} ]] && return
    zellij attach -c
    return
  fi
}

# nvim
[[ -x "$(command -v nvim)" ]] && alias vim="nvim"

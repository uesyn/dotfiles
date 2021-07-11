# kubernetes
alias k='kubectl'
alias ks='kubectl -n kube-system'
alias kx='kubectx'
alias kn='kubens'

# asdf
alias ai='asdf install'
alias al='asdf list all'
alias ag='asdf global'
alias ap='asdf plugin list'

case $OSTYPE in
  linux*)
    alias ll='ls --color -l'
    alias ls='ls --color'
    alias pbcopy='gocopy'
    alias pbpaste='gopaste'
    ;;
  darwin*)
    if [[ -d "${BREW_PREFIX}/opt/coreutils/libexec/gnubin" ]]; then
      alias ll='ls --color -l'
      alias ls='ls --color'
    fi
    if [[ -x "${BREW_PREFIX}/bin/gmake" ]]; then
      alias make="gmake"
    fi
    ;;
esac

alias tm='tmux new-session -ADs main'
alias d='devbox'

# nvim
if [[ -x "$(command -v nvim)" ]];then
  alias vim="nvim"
fi

# kind for Mac arm64
if uname -v | grep ARM64; then
  alias kind="DOCKER_DEFAULT_PLATFORM=linux/arm64 kind"
fi

# kubernetes
alias k='kubectl'
alias ks='kubectl -n kube-system'
alias kx='kubectx'
alias kn='kubens'

detect_target() {
  platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"

  case "${platform}" in
    linux) platform="linux" ;;
    darwin) platform="darwin" ;;
  esac

  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    armv*) arch="arm" ;;
  esac

  printf '%s' "$platform-$arch"
}

function d() {
  if [[ ! -x "$(command -v devbox)" ]]; then
    local devbox=${OPT_DIR}/bin/devbox
    local bin_name
    case "$(detect_target)" in
      darwin-arm64)
        bin_name=devbox_darwin_arm64
        ;;
      darwin-amd64)
        bin_name=devbox_darwin_amd64
        ;;
      linux-amd64)
        bin_name=devbox_linux_amd64
        ;;
      linux-arm64)
        bin_name=devbox_linux_arm64
        ;;
      *) warn "Unsupported platform for aqua: $(detect_target)"; return 0 ;;
    esac
    curl -L -o ${devbox} "https://github.com/uesyn/dotfiles/releases/download/devbox%2Fnightly/${bin_name}"
    chmod +x ${devbox}
  fi
  devbox "$@"
}

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

function t() {
  if [[ -x "$(command -v tmux)" ]]; then
    tmux new-session -ADs main
    return
  fi
}

# nvim
[[ -x "$(command -v nvim)" ]] && alias vim="nvim"

# python
function venv() {
  python -m venv .venv
}

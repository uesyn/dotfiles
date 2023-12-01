if [[ -z ${OLD_PATH} ]]; then
	export OLD_PATH=${PATH}
fi
PATH=${OLD_PATH}

### global
if [[ $OSTYPE =~ linux.* ]]; then
	export LANG=en_US.UTF-8
fi

# common
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

## opt
export OPT_DIR=${OPT_DIR:-${HOME}/opt}
export OPT_BIN=${OPT_DIR}/bin
export OPT_PKGX_BIN=${OPT_DIR}/pkgx/bin
export PATH=${OPT_BIN}:${OPT_PKGX_BIN}:${PATH}

## local zsh
export PATH=${OPT_DIR}/zsh/bin:${PATH}

## neovim
export PATH=${OPT_DIR}/nvim/bin:${PATH}

# go
export GO111MODULE=on
export GOPATH=${HOME}
export GOBIN=${OPT_BIN}

# kubectl
alias k='kubectl'
alias ks='kubectl -n kube-system'
alias kx='kubectx'
alias kn='kubens'
if [[ -x "$(command -v kubectl)" ]]; then
  kubectl() {
    unset -f kubectl
    source <(kubectl completion bash)
    kubectl $@
  }
fi

# krew
export PATH=${PATH}:${HOME}/.krew/bin

# load local bashrc
touch ${HOME}/.bashrc.local
source ${HOME}/.bashrc.local

# raise OPT_BIN path priority
PATH=${OPT_BIN}:$PATH

function z() {
  if [[ -x "$(command -v zellij)" ]]; then
    [[ -n ${ZELLIJ_SESSION_NAME} ]] && return
    zellij attach -c
    return
  fi
}

# nvim
[[ -x "$(command -v nvim)" ]] && alias vim="nvim"

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

function d() {
  if [[ ! -x "$(command -v devk)" ]]; then
    local devk=${OPT_DIR}/bin/devk
    local bin_name
    case "$(detect_target)" in
      darwin-arm64)
        bin_name=devk_darwin_arm64
        ;;
      darwin-amd64)
        bin_name=devk_darwin_amd64
        ;;
      linux-amd64)
        bin_name=devk_linux_amd64
        ;;
      linux-arm64)
        bin_name=devk_linux_arm64
        ;;
      *) warn "Unsupported platform for devk: $(detect_target)"; return 0 ;;
    esac
    curl -sSfL "https://github.com/uesyn/dotfiles/releases/download/devk%2Fnightly/${bin_name}.gz" | gunzip - > ${devk}
    chmod +x ${devk}
  fi
  devk "$@"
}

#docs.pkgx.sh/shellcode
if [[ -x "$(command -v pkgx)" ]]; then
  env () {
    unset -f env
    source <(pkgx --shellcode)
    env "$@"
  }
fi

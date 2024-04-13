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

case $OSTYPE in
  linux*)
    alias ll='\ls --color -l'
    alias ls='\ls --color'
    ;;
  darwin*)
    if [[ -x "$(command -v gls)" ]]; then
      alias ll='\gls --color -l'
      alias ls='\gls --color'
    else
      alias ll='\ls --color -l'
      alias ls='\ls --color'
    fi
    ;;
esac

# nvim
[[ -x "$(command -v nvim)" ]] && alias vim="nvim"

# python
function venv() {
  python -m venv .venv
}

function z() {
  zellij attach -c
}

function tm() {
  tmux new-session -ADs main
}

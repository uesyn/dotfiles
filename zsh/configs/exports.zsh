typeset -Ug path fpath manpath

path=(
  $path
  /usr/local/sbin
  /usr/local/bin
  /usr/sbin
  /usr/bin
  /sbin
  /bin
)

# common
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export LANG=en_US.UTF-8

# Homebrew
[[ -f /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
[[ -f /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
[[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
if [[ -x "$(command -v brew)" ]]; then
  export HOMEBREW_PREFIX=$(brew --prefix)
  path=(
    ${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin(N-/)
    ${HOMEBREW_PREFIX}/opt/gnu-sed/libexec/gnubin(N-/)
    ${HOMEBREW_PREFIX}/opt/grep/libexec/gnubin(N-/)
    ${HOMEBREW_PREFIX}/opt/gnu-tar/libexec/gnubin(N-/)
    ${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin(N-/)
    ${HOMEBREW_PREFIX}/opt/diffutils/bin(N-/)
    $path
  )
fi
export HOMEBREW_NO_AUTO_UPDATE=1

# opt
export OPT_DIR=${OPT_DIR:-${HOME}/opt}
export OPT_BIN=${OPT_DIR}/bin
path=(${OPT_BIN} $path)

# aqua
export AQUA_GLOBAL_CONFIG=${XDG_CONFIG_HOME}/aquaproj-aqua/global_aqua.yaml
path=(${XDG_DATA_HOME}/aquaproj-aqua/bin $path)

# go
export GO111MODULE=on
export GOPATH=${HOME}
export GOBIN=${OPT_BIN}
# not to use GOROOT in github codespace
unset GOROOT

# fzf
export FZF_DEFAULT_OPTS='--height 60% --reverse --border'

# rust
export RUSTUP_HOME=${RUSTUP_HOME:-"${OPT_DIR}/rust/rustup"}
export CARGO_HOME=${CARGO_HOME:-"${OPT_DIR}/rust/cargo"}
[[ -f ${CARGO_HOME}/env ]] && source ${CARGO_HOME}/env
path=(${CARGO_HOME}/bin $path)

# zsh
path=(${OPT_DIR}/zsh/bin $path)

# nvim
if [[ -x $(command -v nvim) ]]; then
  export EDITOR="nvim"
  export KUBE_EDITOR="${EDITOR}"
  export GIT_EDITOR="${EDITOR}"
fi

# dircolors ./dircolors
LS_COLORS='no=0:fi=0:rs=0:di=38;5;109:ln=38;5;175:mh=04:pi=40;33:so=38;5;211:do=38;5;211:bd=40;33;01:cd=40;33;01:or=40;31;01:ow=38;5;109:ex=00;38;5;208:';
export LS_COLORS

# nvm
export NVM_DIR="${XDG_DATA_HOME}/nvm"
if [[ -e "$NVM_DIR/nvm.sh" ]]; then
  alias nvm='unalias nvm node npm && source "$NVM_DIR"/nvm.sh && nvm'
  alias node='unalias nvm node npm && source "$NVM_DIR"/nvm.sh && node'
  alias npm='unalias nvm node npm && source "$NVM_DIR"/nvm.sh && npm'
fi

# jabaa
export JABBA_HOME="$HOME/opt/jabba"
if [[ -s "$JABBA_HOME/jabba.sh" ]]; then
  alias jabba='unalias jabba && source $JABBA_HOME/jabba.sh && jabba'
fi

# raise OPT_BIN path priority
path=(${OPT_BIN} $path)

typeset -Ug path fpath manpath

# Default PATH
path=($path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin)

# Homebrew
[[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
[[ -x $(command -v brew) ]] && export BREW_PREFIX="$(dirname $(dirname $(command -v brew)))"

# coreutils
path=(${BREW_PREFIX}/opt/coreutils/libexec/gnubin(N-/) $path)
# gnu-sed
path=(${BREW_PREFIX}/opt/gnu-sed/libexec/gnubin(N-/) $path)
# gnu grep
path=(${BREW_PREFIX}/opt/grep/libexec/gnubin(N-/) $path)
# gnu tar
path=(${BREW_PREFIX}/opt/gnu-tar/libexec/gnubin(N-/) $path)
# findutils tar
path=(${BREW_PREFIX}/opt/findutils/libexec/gnubin(N-/) $path)
# diffutils
path=(${BREW_PREFIX}/opt/diffutils/bin(N-/) $path)

# opt
export OPT_DIR=${OPT_DIR:-${HOME}/opt}
export OPT_BIN=${OPT_DIR}/bin
path=(${OPT_BIN}(N-/) $path)

# dircolors
dircolros_conf="${HOME}/.dircolors"
[[ -x "$(command -v dircolors)" ]] && [[ -f ${dircolros_conf} ]] && eval "$(dircolors ${dircolros_conf})"

# krew
path=(${HOME}/.krew/bin(N-/) $path)

# asdf
export ASDF_DIR=${HOME}/.asdf
export ASDF_DATA_DIR=${ASDF_DATA_DIR:-${HOME}/.asdf}
[[ -f ${ASDF_DIR}/asdf.sh ]] && source ${ASDF_DIR}/asdf.sh
export NODEJS_CHECK_SIGNATURES=no

# go
export GO111MODULE=on
export GOPATH=${HOME}
export GOBIN=${HOME}/bin
path=(${GOBIN} $path)

# ghq
export GHQ_ROOT="${HOME}/src"

# fzf
export FZF_DEFAULT_OPTS='--height 60% --reverse --border'

# zsh
export WORDCHARS="?!"
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
ZSHENV_LOCAL=${HOME}/.zshenv.local
touch $ZSHENV_LOCAL && source $ZSHENV_LOCAL
if [[ -z "$skip_global_compinit" ]] && [[ -f /etc/os-release ]] && grep -q '^ID.*=.*ubuntu' /etc/os-release; then
  skip_global_compinit=1
fi

# rust
export RUSTUP_HOME=${RUSTUP_HOME:-"${OPT_DIR}/rust/rustup"}
export CARGO_HOME=${CARGO_HOME:-"${OPT_DIR}/rust/cargo"}
[[ -f ${CARGO_HOME}/env ]] && source ${CARGO_HOME}/env

# nvim
if [[ -x $(command -v nvim) ]]; then
  export EDITOR=nvim
  export KUBE_EDITOR=nvim
  export GIT_EDITOR=nvim
fi

# tmux
export TMUX_PLUGINS=${OPT_DIR}/tmux/plugins

# gcloud
[[ -d ${HOME}/opt/google-cloud-sdk/bin ]] && path=(${HOME}/opt/google-cloud-sdk/bin $path)

# dotfiles
path=(${HOME}/.bin $path)

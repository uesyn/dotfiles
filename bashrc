if [[ -z ${OLD_PATH} ]]; then
	export OLD_PATH=${PATH}
fi
PATH=${OLD_PATH}

function tm() {
  [[ -n ${TMUX} ]] && return
  tmux new-session -ADs main
}

function z() {
  [[ -n ${ZELLIJ_SESSION_NAME} ]] && return
  zellij attach -c
}

### global
if [[ $OSTYPE =~ linux.* ]]; then
	export LANG=en_US.UTF-8
fi

# common
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# aqua
export AQUA_GLOBAL_CONFIG=${XDG_CONFIG_HOME}/aquaproj-aqua/global_aqua.yaml
export PATH=${XDG_DATA_HOME}/aquaproj-aqua/bin:${PATH}

## opt
export OPT_DIR=${OPT_DIR:-${HOME}/opt}
export OPT_BIN=${OPT_DIR}/bin
export PATH=${OPT_BIN}:${PATH}

## local zsh
export PATH=${OPT_DIR}/zsh/bin:${PATH}

# go
export GO111MODULE=on
export GOPATH=${HOME}
export GOBIN=${OPT_BIN}

# load local bashrc
touch ${HOME}/.bashrc.local && source ${HOME}/.bashrc.local

# raise OPT_BIN path priority
PATH=${OPT_BIN}:$PATH

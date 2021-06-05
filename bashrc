if [[ -z ${OLD_PATH} ]]; then
	export OLD_PATH=${PATH}
fi
PATH=${OLD_PATH}

alias tm='tmux new-session -ADs main'

### global
if [[ $OSTYPE =~ linux.* ]]; then
	export LANG=en_US.UTF-8
fi

## brew
if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
fi

## opt
export OPT_DIR=${OPT_DIR:-${HOME}/opt}
export PATH=${OPT_DIR}/bin:${PATH}

## krew
export PATH="${PATH}:${HOME}/.krew/bin"

## PATH for My script and GOBIN
export PATH="${HOME}/bin:${PATH}"

# go
export GO111MODULE=on
export GOPATH=${HOME}
export GOBIN=${HOME}/bin

# asdf
export ASDF_DIR=${HOME}/.asdf
export ASDF_DATA_DIR=/tmp/asdf
[[ -f ${ASDF_DIR}/asdf.sh ]] && source ${ASDF_DIR}/asdf.sh
export NODEJS_CHECK_SIGNATURES=no

# dotfiles
export PATH=${PATH}:${HOME}/.bin

# load local bashrc
touch ${HOME}/.bashrc.local && source ${HOME}/.bashrc.local

alias d='devbox'

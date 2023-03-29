lazynvm() {
  unset -f nvm node npm nvim
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
}

nvm() {
  lazynvm
  nvm $@
}

node() {
  lazynvm
  node $@
}

npm() {
  lazynvm
  npm $@
}

nvim() {
  lazynvm
  nvim $@
}

if [[ -x "$(command -v kubectl)" ]]; then
  kubectl() {
    unset -f kubectl
    source <(kubectl completion zsh)
    kubectl $@
  }
fi

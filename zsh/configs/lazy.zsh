if [[ -x "$(command -v kubectl)" ]]; then
  kubectl() {
    unset -f kubectl
    source <(kubectl completion zsh)
    kubectl $@
  }
fi

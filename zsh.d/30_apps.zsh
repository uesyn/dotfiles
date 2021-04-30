autoload -Uz add-zsh-hook

function tmux_hook() {
  if [[ -z ${TMUX} ]]; then
    return
  fi
  tmux set-option -gq "@tmux_kubecontext_kubeconfig_#{pane_id}-#{session_id}-#{window_id}" "${KUBECONFIG}"
}

add-zsh-hook precmd tmux_hook

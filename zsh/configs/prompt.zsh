function _kube_prompt() {
  local kubeconfig
  kubeconfig="${KUBECONFIG:-${HOME}/.kube/config}"
  if [[ ! -f "${kubeconfig}" ]]; then
    echo -n ""
    return
  fi

  if [[ ! -x "$(command -v kubectl)" ]]; then
    echo -n "%F{#83a598}[error: kubectl command not found]%f "
    return
  fi

  local context tmp_context
  context=$(kubectl config current-context 2>&1)
  if [[ $? -ne 0 ]]; then
    [[ $context = "error: current-context is not set" ]] && return
    echo -n "%F{#83a598}⎈ failed to execute kubectl%f "
    return
  fi

  for prefix in ${PROMPT_KUBE_TRIM_PREFIX[@]}; do
    tmp_context=${context#${prefix}}
    if [[ ${tmp_context} != ${context} ]]; then
      context=${tmp_context}
      break
    fi
  done

  if [[ -n ${PROMPT_KUBE_IMPORT_CONTEXT_PATTERN} ]] && [[ ${context} =~ ${PROMPT_KUBE_IMPORT_CONTEXT_PATTERN} ]]; then
    echo -n "%K{#ff0000}%F{#ffffff}⎈ ${context}%f%k "
    return
  fi
  echo -n "%F{#83a598}⎈ ${context}%f "
}

function _shutdown_prompt() {
  if [[ -f "/tmp/stopping" ]]; then
    echo -n " %K{#ff0000}%F{#ffffff}[STOPPING]%f%k"
  fi
}

function _my_prompt() {
  local os_prompt dir_prompt git_prompt shutdown_prompt

  shutdown_prompt='$(_shutdown_prompt)'

  os_prompt=""
  case $OSTYPE in
    darwin*) os_prompt=" %F{#8ec07c} %f" ;;
    linux*) os_prompt=" %F{#8ec07c} %f" ;;
  esac
  if [[ -n "${PROMPT_ICON}" ]]; then
    os_prompt=" %F{#8ec07c}${PROMPT_ICON} %f"
  fi

  short_dir_prompt="%c"

  dir_prompt="%F{#fabd2f} %f%~"

  ZSH_GIT_PROMPT_SHOW_UPSTREAM="no"
  ZSH_THEME_GIT_PROMPT_PREFIX="%B %b"
  ZSH_THEME_GIT_PROMPT_SUFFIX=""
  ZSH_THEME_GIT_PROMPT_SEPARATOR=""
  ZSH_THEME_GIT_PROMPT_BRANCH="%F{#fe8019} "
  ZSH_THEME_GIT_PROMPT_DETACHED="%F{#fe8019}:"
  ZSH_THEME_GIT_PROMPT_BEHIND="%F{#fe8019}↓"
  ZSH_THEME_GIT_PROMPT_AHEAD="%F{#fe8019}↑"
  ZSH_THEME_GIT_PROMPT_UNMERGED="%F{#fe8019}✖"
  ZSH_THEME_GIT_PROMPT_STAGED="%F{#fe8019}+"
  ZSH_THEME_GIT_PROMPT_UNSTAGED="%F{#fe8019}!"
  ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{#fe8019}…"
  ZSH_THEME_GIT_PROMPT_STASHED="%F{#fe8019}⚑"
  ZSH_THEME_GIT_PROMPT_CLEAN=""
  git_prompt='$(gitprompt) '

  kube_prompt='$(_kube_prompt)'

  PROMPT="${shutdown_prompt}${os_prompt}${short_dir_prompt}${git_prompt}${kube_prompt}%F{#a89984}%f "
  RPROMPT="${dir_prompt}"
}

if [[ -x "$(command -v starship)" ]]; then
  source <(starship init zsh)
else
  _my_prompt
fi

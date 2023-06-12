function _kube_prompt() {
  local kubeconfig
  kubeconfig="${KUBECONFIG:-${HOME}/.kube/config}"
  if [[ -z ${kubeconfig} ]]; then
    return
  fi
  if [[ ! -f "${kubeconfig}" ]]; then
    return
  fi

  local context context_line tmp_context
  context_line=$(grep "current-context:" ${kubeconfig})
  context=${context_line#"current-context: "}
  if [[ -z "$context" ]]; then
    return
  fi

  local prefixes
  prefixes=($(tr "," " " <<<"${PROMPT_KUBE_TRIM_PREFIX}"))
  for prefix in ${prefixes[@]}; do
    tmp_context="${context#${prefix}}"
    if [[ ${tmp_context} != ${context} ]]; then
      context="${tmp_context}"
      break
    fi
  done

  if [[ -n ${PROMPT_KUBE_IMPORT_CONTEXT_PATTERN} ]] && [[ ${context} =~ ${PROMPT_KUBE_IMPORT_CONTEXT_PATTERN} ]]; then
    echo -n " %K{#ff0000}%F{#ffffff}⎈ ${context}%f%k"
    return
  fi
  echo -n " %F{#8be9fd}⎈ ${context}%f"
}

ZSH_GIT_PROMPT_SHOW_UPSTREAM="no"
ZSH_THEME_GIT_PROMPT_PREFIX="%B%b"
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_SEPARATOR=""
ZSH_THEME_GIT_PROMPT_BRANCH="%F{#ffb86c} "
ZSH_THEME_GIT_PROMPT_DETACHED="%F{#ffb86c}:"
ZSH_THEME_GIT_PROMPT_BEHIND="%F{#ffb86c}↓"
ZSH_THEME_GIT_PROMPT_AHEAD="%F{#ffb86c}↑"
ZSH_THEME_GIT_PROMPT_UNMERGED="%F{#ffb86c}✖"
ZSH_THEME_GIT_PROMPT_STAGED="%F{#ffb86c}+"
ZSH_THEME_GIT_PROMPT_UNSTAGED="%F{#ffb86c}!"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{#ffb86c}…"
ZSH_THEME_GIT_PROMPT_STASHED="%F{#ffb86c}⚑"
ZSH_THEME_GIT_PROMPT_CLEAN=""

function _git_prompt() {
  local p
  p="$(gitprompt)"
  if [[ -n ${p} ]]; then
    echo -n " ${p}"
  fi
}

function _shutdown_prompt() {
  if [[ -f "/tmp/stopping" ]]; then
    echo -n " %K{#ff0000}%F{#ffffff}[STOPPING]%f%k"
  fi
}

function _python_prompt() {
  if [[ -n "${VIRTUAL_ENV}" ]]; then
    echo -n " 🐍 %F{#99CC33}venv%f"
  fi
}

function _my_prompt() {
  local os_prompt dir_prompt git_prompt shutdown_prompt kube_prompt python_prompt short_dir_prompt

  shutdown_prompt='$(_shutdown_prompt)'
  os_prompt=""
  case $OSTYPE in
    darwin*) os_prompt=" %F{#ff79c6} %f" ;;
    linux*) os_prompt=" %F{#ff79c6} %f" ;;
  esac
  if [[ -n "${PROMPT_ICON}" ]]; then
    os_prompt=" %F{#ff79c6}${PROMPT_ICON} %f"
  fi
  short_dir_prompt="%c"
  dir_prompt=" %F{#fabd2f} %f%~"
  git_prompt='$(_git_prompt)'
  kube_prompt='$(_kube_prompt)'
  python_prompt='$(_python_prompt)'
  PROMPT="${shutdown_prompt}${os_prompt}${short_dir_prompt}${git_prompt}${kube_prompt}${python_prompt}${new_line}
 %F{#a89984}%f "
  RPROMPT="${dir_prompt}"
}

if [[ -x "$(command -v starship)" ]]; then
  source <(starship init zsh)
else
  _my_prompt
fi

setopt PROMPT_SUBST

_git_info() {
  cd -q $1
  vcs_info
  print ${vcs_info_msg_0_}
}

_git_info_done() {
  local code=$2
  local stdout=$3

  # when async worker crashes
  if (( code != 0 )); then
    async_stop_worker git_info
    _git_info_prompt_init
  fi

  _git_info_prompt="$stdout "
  zle reset-prompt
}

_git_info_precmd() {
  async_flush_jobs git_info
  async_job git_info _git_info $PWD
}

_git_info_prompt_init() {
  autoload -Uz vcs_info
  typeset -g _git_info_prompt=''

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:git:*' check-for-changes true
  zstyle ':vcs_info:git:*' stagedstr "!"
  zstyle ':vcs_info:git:*' unstagedstr "+"
  zstyle ':vcs_info:git:*' formats ' %b%c%u'
  zstyle ':vcs_info:git:*' actionformats ' %b<%a>%c%u'

  async_start_worker git_info
  async_register_callback git_info _git_info_done
  add-zsh-hook precmd _git_info_precmd
}

_kubernetes_info() {
  if [[ ! -f ${KUBECONFIG:-${HOME}/.kube/config} ]]; then
    return
  fi

  if [[ ! -x $(command -v kubectl) ]]; then
    return
  fi

  context="$(kubectl config current-context 2>/dev/null)"
  print ${context}
}

_kubernetes_info_done() {
  local code=$2
  local stdout=$3

  # when async worker crashes
  if (( code != 0 )); then
    async_stop_worker kubernetes_info
    _kubernetes_prompt_init
  fi

  if [[ -n $stdout ]]; then
    _kubernetes_prompt="☸  $stdout "
  else
    _kubernetes_prompt=""
  fi
  zle reset-prompt
}

_kubernetes_info_precmd() {
  async_flush_jobs kubernetes_info 
  async_job kubernetes_info _kubernetes_info
}

_kubernetes_prompt_init() {
  typeset -g _kubernetes_prompt=''
  async_start_worker kubernetes_info
  async_register_callback kubernetes_info _kubernetes_info_done
  add-zsh-hook precmd _kubernetes_info_precmd
}

_venv_info() {
  VENV=$1
  print ${VENV##*/}
}

_venv_info_done() {
  local code=$2
  local stdout=$3

  # when async worker crashes
  if (( code != 0 )); then
    async_stop_worker venv_info
    _venv_prompt_init
  fi

  if [[ -n $stdout ]]; then
    _venv_prompt="🐍 $stdout "
  else
    _venv_prompt=""
  fi
  zle reset-prompt
}

_venv_info_precmd() {
  async_flush_jobs venv_info 
  async_job venv_info _venv_info $VIRTUAL_ENV
}

_venv_prompt_init() {
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  typeset -g _venv_prompt=''
  async_start_worker venv_info
  async_register_callback venv_info _venv_info_done
  add-zsh-hook precmd _venv_info_precmd
}

prompt_init() {
  new_line=$'\n'

  async_init
  _git_info_prompt_init
  _kubernetes_prompt_init
  _venv_prompt_init

  PROMPT='╭─   %n ${_git_info_prompt}${_kubernetes_prompt}${_venv_prompt}${new_line}╰─❯ '
  RPROMPT='%~'
}

prompt_init

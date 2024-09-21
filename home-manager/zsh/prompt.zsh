setopt PROMPT_SUBST

_git_info() {
  cd -q $1
  local ab=""
  local ahead=0
  local behind=0
  local staged=0
  local unstaged=0
  local unmerged=0
  local untracked=0
  local ignored=0
  local git_prompt=""
  local repo_condition=""

  if ! command git rev-parse --git-dir >/dev/null 2>&1; then
    return
  fi
  
  while read -r line; do
    case "$line" in
      "# branch.oid "*) oid="${line#\# branch.oid }" ;;
      "# branch.head "*) head="${line#\# branch.head }" ;;
      "# branch.upstream "*) upstream="${line#\# branch.upstream }" ;;
      "# branch.ab "*) ab="${line#\# branch.ab }" ;;
      1* | 2*)
        line="${line#* }"
        xy="${line%% *}"
        case "$(echo "$xy" | cut -c1)" in
          M|A|D|R|C) staged=$((staged + 1)) ;;
        esac
        case "$(echo "$xy" | cut -c2)" in
          M|A|D|R|C) unstaged=$((unstaged + 1)) ;;
        esac
        ;;
      "u "*) unmerged=$((unmerged + 1)) ;;
      "? "*) untracked=$((untracked + 1)) ;;
      "! "*) ignored=$((ignored + 1)) ;;
      *) "$line: invalid git status line" ;;
    esac
  done < <(git status --porcelain=v2 --branch)
  
  if [ -n "$ab" ]; then
    ahead="${ab% -*}"
    ahead="${ahead#+}"
    behind="${ab#+* }"
    behind="${behind#-}"
  fi
  
  git_prompt="${head}"
  if [[ -n "${upstream}" ]]; then
    git_prompt="${git_prompt}..${upstream}"
    if [[ "${ahead}" -gt 0 ]]; then
      repo_condition="${repo_condition} ↑${ahead}"
    fi
    if [[ "${behind}" -gt 0 ]]; then
      repo_condition="${repo_condition} ↓${behind}"
    fi
  fi
  
  if [[ "${staged}" -gt 0 ]]; then
    repo_condition="${repo_condition} +${staged}"
  fi
  
  if [[ "${unstaged}" -gt 0 ]]; then
    repo_condition="${repo_condition} !${unstaged}"
  fi
  
  if [[ "${untracked}" -gt 0 ]]; then
    repo_condition="${repo_condition} ?${untracked}"
  fi

  if [[ "${unmerged}" -gt 0 ]]; then
    repo_condition="${repo_condition} x{unmerged}"
  fi

  repo_condition=${repo_condition# }

  if [[ -n ${repo_condition} ]]; then
    git_prompt="${git_prompt} %F{#ffb86c}%f%K{#ffb86c}%F{#f8f8f2}${repo_condition}%f%k%F{#ffb86c}%f"
  fi
  
  print "%F{#ffb86c}%f ${git_prompt}"
}

_git_info_done() {
  local code=$2
  local stdout=$3

  # when async worker crashes
  if (( code != 0 )); then
    async_stop_worker git_info
    _git_info_prompt_init
  fi

  if [[ -n $stdout ]]; then
    _git_info_prompt="$stdout "
  else
    _git_info_prompt=""
  fi
  zle reset-prompt
}

_git_info_precmd() {
  async_flush_jobs git_info
  async_job git_info _git_info $PWD
}

_git_info_prompt_init() {
  autoload -Uz vcs_info
  typeset -g _git_info_prompt=''

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
    _kubernetes_prompt="%F{#8be9fd}⎈ %f$stdout "
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

  PROMPT='%F{#6272a4}╭─%f %F{#ff5555} %f %n 📁 %2d ${_git_info_prompt}${_kubernetes_prompt}${_venv_prompt}${new_line}%F{#6272a4}╰─%f%F{#bd93f9}❯%f '
  RPROMPT='📁 %~'
}

prompt_init

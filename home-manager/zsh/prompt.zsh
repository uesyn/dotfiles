setopt PROMPT_SUBST

autoload -U add-zsh-hook

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
  done < <(git --no-optional-locks status --porcelain=v2 --branch)

  if [ -n "$ab" ]; then
    ahead="${ab% -*}"
    ahead="${ahead#+}"
    behind="${ab#+* }"
    behind="${behind#-}"
  fi

  if [[ "${head}" == "(detached)" ]]; then
    tag=$(git tag --points-at HEAD)
    if [[ -n "${tag}" ]]; then
      head="${tag}"
    fi
  fi

  git_prompt="${head}"
  if [[ -n "${upstream}" ]]; then
    _tmp_prompt="${git_prompt}"
    if [[ "${ahead}" -gt 0 ]]; then
      repo_condition="${repo_condition} ↑${ahead}"
      _tmp_prompt="${git_prompt}..${upstream}"
    fi
    if [[ "${behind}" -gt 0 ]]; then
      repo_condition="${repo_condition} ↓${behind}"
      _tmp_prompt="${git_prompt}..${upstream}"
    fi
    git_prompt="${_tmp_prompt}"
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
    repo_condition="${repo_condition} x${unmerged}"
  fi

  repo_condition=${repo_condition# }

  if [[ -n ${repo_condition} ]]; then
    git_prompt="${git_prompt} %F{#ff5555}%f%K{#ff5555}%F{#f8f8f2}${repo_condition}%f%k%F{#ff5555}%f"
  fi

  print "%F{#ff5555}%f ${git_prompt}"
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
  export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
  local context=""

  if [[ -x $(command -v kubectx) ]]; then
    context="$(kubectx -c 2>/dev/null)"
  elif [[ -x $(command -v kubectl) ]]; then
    context="$(kubectl config current-context 2>/dev/null)"
  fi

  if [[ -z "$context" ]]; then
    return
  fi

  print "%F{#8be9fd}⎈ %f${context}"
}

_venv_info() {
  VENV=${VIRTUAL_ENV/"${HOME}"/'~'}
  if [[ -n $VENV ]]; then
    print "🐍 ${VENV}"
  fi
}

_ssh_prompt() {
  if [[ -n $SSH_CONNECTION ]]; then
    print "🌐 %m "
  fi
}

prompt_init() {
  export VIRTUAL_ENV_DISABLE_PROMPT=1

  async_init
  _git_info_prompt_init

  PROMPT='%F{#6272a4}╭─%f %F{#ffb86c} %f %n $(_ssh_prompt)📁 %2d ${_git_info_prompt}$(_kubernetes_info)$(_venv_info)
%F{#6272a4}╰─%f%F{#bd93f9}❯%f '
  RPROMPT='📁 %~'
}

prompt_init

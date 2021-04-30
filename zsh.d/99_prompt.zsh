setopt prompt_subst
autoload -U colors; colors

_prompt_color_white=223

_prompt_color_dark_red=124
_prompt_color_dark_green=106
_prompt_color_dark_yellow=172
_prompt_color_dark_blue=66
_prompt_color_dark_purple=132
_prompt_color_dark_aqua=72
_prompt_color_dark_gray=245
_prompt_color_dark_orange=166

_prompt_color_red=167
_prompt_color_green=142
_prompt_color_yellow=214
_prompt_color_blue=109
_prompt_color_purple=175
_prompt_color_aqua=108
_prompt_color_gray=246
_prompt_color_orange=208

function _show_prompt_symbol(){
  local user_symbol color=$1 dark_color=$2
  user_symbol='%B%F{'${dark_color}'}>>%f%F{'${color}'}>%f%b '
  echo $user_symbol
}

function _show_segment_with_color(){
  local fg=$1
  local content=$2
  local symbol=$3
  local output=''
  
  if [[ -z $symbol ]]; then
    output="${content}"
  else
    output="${symbol} ${content}"
  fi

  if [[ -n $content ]]; then
    echo -n "%B%F{$1}${output}%f%b"
  fi
}

function _show_message(){
  local content=$1
  local color=$2
  if [[ -n $color ]]; then
    echo -n "%F{$2}${content}%f"
  else
    echo -n "${content}"
  fi
}

function _prompt_pwd(){
  local color=$1
  local path="%~"
  local count current_dir

  current_dir=$(pwd)
  if [[ $current_dir =~ ^${HOME} ]]; then
    current_dir=${current_dir/${HOME}/"~"}
  fi

  if [[ ${#current_dir} -gt 80 ]]; then
    path="~/.../%3~"
  fi

  _show_message "in" ${_prompt_color_white}
  _prompt_space

  _show_segment_with_color "${color}" "${path}"
  _prompt_space
}


function _prompt_git(){
  local color=$1
  [[ -z "$(command -v gitstatus_query)" ]] && return
  gitstatus_query MY && [[ $VCS_STATUS_RESULT != 'ok-sync' ]] && return

  local where  # branch name, tag or commit
  if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
    where=$VCS_STATUS_LOCAL_BRANCH
  elif [[ -n $VCS_STATUS_TAG ]]; then
    p+='%f#'
    where=${VCS_STATUS_TAG}(tag)
  else
    p+='%f@'
    where=${VCS_STATUS_COMMIT[1,8]}
  fi
  local commit_status
  (( VCS_STATUS_NUM_STAGED    )) && commit_status+="+${VCS_STATUS_NUM_STAGED}"
  (( VCS_STATUS_NUM_UNSTAGED  )) && commit_status+="!${VCS_STATUS_NUM_UNSTAGED}"
  (( VCS_STATUS_NUM_UNTRACKED )) && commit_status+="?${VCS_STATUS_NUM_UNTRACKED}"
  (( VCS_STATUS_COMMITS_AHEAD )) && commit_status+="⇡${VCS_STATUS_COMMITS_AHEAD}"
  (( VCS_STATUS_COMMITS_BEHIND )) && commit_status+="⇡${VCS_STATUS_COMMITS_BEHIND}"
  (( VCS_STATUS_NUM_CONFLICTED )) && commit_status+="~${VCS_STATUS_NUM_CONFLICTED}"

  if [[ -n $commit_status ]]; then
    where="${where} ${commit_status}"
  fi

  _show_message "on" ${_prompt_color_white}
  _prompt_space
  _show_segment_with_color "${color}" "${where}" ""
  _prompt_space
}

function _prompt_kubernetes(){
  local color=$1
  if [[ -z $KUBECONFIG ]]; then
    return
  fi
  local contents

  _show_message "with" ${_prompt_color_white}
  _prompt_space
  _show_segment_with_color "${color}" "KUBECONFIG=${KUBECONFIG}"
  _prompt_space
}

function _prompt_username(){
  local color=$1
  _show_segment_with_color "${color}" "%n"
  _prompt_space
}

function _prompt_line(){
  echo ""
}

function _prompt_space(){
  echo -n " "
}

function _show_prompt(){
  _prompt_username ${_prompt_color_aqua}
  _prompt_pwd ${_prompt_color_green}
  _prompt_git ${_prompt_color_purple}
  _prompt_kubernetes ${_prompt_color_dark_blue}
  _prompt_line
  _show_prompt_symbol ${_prompt_color_yellow} ${_prompt_color_dark_yellow}
}

PROMPT='$(_show_prompt)'

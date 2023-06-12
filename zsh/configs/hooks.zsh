autoload -U add-zsh-hook

get_venv_path() {
  local venv_types=(".venv" "venv")
  local d

  for venv in "${venv_types[@]}"; do
    d=${PWD}
    while true; do
      [[ -z "${d}" ]] && break
      vpath=${d}/${venv}
      if [[ -d ${vpath} ]]; then
        echo -n ${vpath}
	return
      fi
      d=${d%/*}
    done
  done
}

auto_python_venv() {
  local d=${PWD}
  local vpath="$(get_venv_path)"

  if [[ -n ${vpath} ]]; then
    source ${vpath}/bin/activate > /dev/null 2>&1
    return
  fi

  if [[ -n "$(command -v deactivate)" ]]; then
    deactivate > /dev/null 2>&1
  fi
}

add-zsh-hook chpwd auto_python_venv
auto_python_venv

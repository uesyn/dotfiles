autoload -U add-zsh-hook

get_venv_path() {
  local venv_types=(".venv" "venv")
  local d

  d=${PWD}
  while true; do
    [[ -z "${d}" ]] && break

    for venv in "${venv_types[@]}"; do
      vpath=${d}/${venv}
      if [[ -d ${vpath} ]] && [[ -f ${vpath}/bin/activate ]]; then
        echo -n ${vpath}
        return
      fi
    done

    d=${d%/*}
  done
}

autoload_python_venv() {
  local vpath="$(get_venv_path)"

  if [[ -z "${vpath}" ]]; then
    if [[ -n "$(command -v deactivate)" ]]; then
      deactivate
    fi
    return
  fi

  if [[ "$VIRTUAL_ENV" == "${vpath}" ]]; then
    return
  fi

  if [[ -n "$(command -v deactivate)" ]]; then
    deactivate
  fi
  source ${vpath}/bin/activate
}

add-zsh-hook precmd autoload_python_venv

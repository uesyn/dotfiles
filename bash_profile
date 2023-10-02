if [[ -f ~/.bashrc ]]; then
	. ~/.bashrc
fi

#docs.pkgx.sh/shellcode
if [[ -x "$(command -v pkgx)" ]]; then
  env () {
    unset -f env
    source <(pkgx --shellcode)
    env "$@"
  }
fi

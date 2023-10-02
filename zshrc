[[ -f ${HOME}/.zlogin ]] && source ${HOME}/.zlogin

for config (
	"exports"
	"load"
	"widgets"
	"bindkeys"
	"options"
	"alias"
	"git-prompt"
	"prompt"
	"hooks"
	"completion"
) {
  source ${HOME}/.config/zsh/configs/${config}.zsh
}

unset config

#docs.pkgx.sh/shellcode
if [[ -x "$(command -v pkgx)" ]]; then
  env () {
    unset -f env
    source <(pkgx --shellcode)
    env "$@"
  }
fi

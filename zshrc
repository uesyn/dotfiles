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
) {
  source ${HOME}/.config/zsh/configs/${config}.zsh
}

unset config

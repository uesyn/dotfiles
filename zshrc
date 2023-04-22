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
	"lazy"
) {
  source ${HOME}/.config/zsh/configs/${config}.zsh
}

unset config

test -d "$HOME/.tea" && source <(tea --magic=zsh --silent)

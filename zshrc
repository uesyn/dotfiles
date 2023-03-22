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
	"completions"
) {
  source ${HOME}/.config/zsh/configs/${config}.zsh
}

unset config

# This line exists not to be overwritten zshrc by sdkman-init.sh.

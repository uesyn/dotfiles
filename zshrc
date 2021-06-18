if [[ -z ${HOME} ]]; then
  return
fi

source ${HOME}/.zshenv

if [[ ! -d ${HOME}/.zinit/bin ]]; then
  git clone --depth=1 https://github.com/zdharma/zinit.git ${HOME}/.zinit/bin
fi
source ~/.zinit/bin/zinit.zsh
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit ice lucid from"gh-r" as"program"
zinit light junegunn/fzf
zinit ice lucid from"gh-r" as"program" mv"hub-*/bin/hub -> hub"
zinit light github/hub
zinit ice lucid from"gh-r" as"program" mv"direnv* -> direnv" atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' pick'direnv' src="zhook.zsh"
zinit light direnv/direnv
zinit ice lucid from"gh-r" as"program" mv"gh_*/bin/gh -> gh" bpick"*.tar.gz" 
zinit light cli/cli
zinit ice lucid from"gh-r" as"program" mv"ripgrep-*/rg -> rg" bpick"*.tar.gz" nocompletions
zinit light BurntSushi/ripgrep
zinit ice lucid from"gh-r" as"program" mv"ghq_*/ghq -> ghq"
zinit light x-motemen/ghq
zinit ice lucid from"gh-r" as"program" mv"jq-* -> jq"
zinit light stedolan/jq
zinit ice lucid from"gh-r" as"program" mv"yq_* -> yq"
zinit light mikefarah/yq
zinit ice lucid from"gh-r" as"program" bpick"*.tar.gz"
zinit light starship/starship

zinit ice lucid from"gh-r" as"program" id-as"kubectx" bpick"kubectx_*"
zinit light ahmetb/kubectx
zinit ice lucid from"gh-r" as"program" id-as"kubens" bpick"kubens_*"
zinit light ahmetb/kubectx
zinit ice lucid from"gh-r" as"program" id-as"stern" mv"stern*/stern -> stern"
zinit light stern/stern
zinit ice lucid from"gh-r" as"program" id-as"kind" mv"kind* -> kind"
zinit light kubernetes-sigs/kind

zinit ice wait'!0' lucid depth"1" atload'gitstatus_stop "MY" && gitstatus_start -s -1 -u -1 -c -1 -d -1 "MY"'
zinit light romkatv/gitstatus
zinit ice wait'!1' lucid depth"1"
zinit light zdharma/history-search-multi-word
zinit ice wait'!1' lucid depth"1"
zinit light paulirish/git-open
zinit ice wait'!2' lucid depth"1"
zinit wait lucid light-mode blockf for blockf atpull'zinit creinstall -q .' \
	atinit"zicompinit; zicdreplay" \
	zsh-users/zsh-completions
zinit ice lucid depth"1"
zinit light qoomon/zsh-lazyload

lazyload kubectl -- 'source <(kubectl completion zsh)'
lazyload k -- 'source <(kubectl completion zsh)'
lazyload stern -- 'source <(stern --completion=zsh)'
lazyload kind -- 'source <(kind completion zsh; echo compdef _kind kind)'

for file (${HOME}/.zsh.d/*.zsh){
  source $file
}

autoload -Uz ${HOME}/.zsh.d/functions/*

ZSHRC_LOCAL=${HOME}/.zshrc.local
[[ ! -f $ZSHRC_LOCAL ]] && touch ${ZSHRC_LOCAL}
source ${ZSHRC_LOCAL}

touch ${HOME}/.gitconfig.local

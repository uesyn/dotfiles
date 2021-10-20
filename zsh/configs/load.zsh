autoload -Uz compinit && compinit
autoload -Uz ${HOME}/.config/zsh/functions/*

foreach module (
  complete
  zle
) {
  zmodload zsh/$module
}
unset module

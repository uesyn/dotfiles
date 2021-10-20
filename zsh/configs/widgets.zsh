# Register functions as widgets.
foreach widget (
  user-fuzzy-history
) {
  eval zle -N $widget
}
unset widget

# Select command from history into the command line.
function user-fuzzy-history() {
  if ! (( $+commands[fzf] )) {
    return 1
  }

  setopt LOCAL_OPTIONS NO_GLOB_SUBST NO_POSIX_BUILTINS PIPE_FAIL 2>/dev/null

  local selected=($(
    fc -l 1 \
    | fzf \
      --tac \
      --nth='2..,..' \
      --tiebreak='index' \
      --query="${LBUFFER}" \
      --exact
  ))

  local stat=$?

  if [[ "$selected" != '' ]] {
    local num=$selected[1]

    if [[ "$num" != '' ]] {
      zle vi-fetch-history -n $num
    }
  }

  zle reset-prompt
  return $stat
}

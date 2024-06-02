typeset -Ug path fpath manpath

path=(
  $path
  /usr/local/sbin
  /usr/local/bin
  /usr/sbin
  /usr/bin
  /sbin
  /bin
)

# common
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Homebrew
[[ -f /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
[[ -f /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
export HOMEBREW_NO_AUTO_UPDATE=1

# nix
if [[ -f ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh ]]; then
  source ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
fi
export TERMINFO_DIRS="/usr/share/terminfo:${HOME}/.nix-profile/share/terminfo"
path=(${HOME}/.nix-profile/bin $path)

# go
export GOPATH=${HOME}
export GOBIN=${HOME}/bin

# Rust
path=(${GOBIN} ${HOME}/.cargo/bin $path)

# fzf
export FZF_DEFAULT_OPTS='--height 60% --reverse --border'

# krew
path=(${KREW_ROOT:-$HOME/.krew}/bin $path)

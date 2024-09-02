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

# nix
nix_paths=(
  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  /etc/profiles/per-user/${USER}/etc/profile.d/hm-session-vars.sh
)
for p in "${nix_paths[@]}"; do
  if [[ -f ${p} ]]; then
    source ${p}
  fi
done
path=(${HOME}/.nix-profile/bin $path)

# Homebrew
[[ -f /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
[[ -f /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
export HOMEBREW_NO_AUTO_UPDATE=1

# fzf
export FZF_DEFAULT_OPTS='--height 60% --reverse --border'

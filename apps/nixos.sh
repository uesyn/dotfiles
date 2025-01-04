target=$1
if [[ -z ${target} ]]; then
  echo "must set target as argument"
  exit 1
fi

nixos-rebuild switch --use-remote-sudo --flake .#"${target}"

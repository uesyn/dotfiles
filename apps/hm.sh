target=$1
if [[ -n ${target} ]]; then
  target="#${target}"
fi

nix run --extra-experimental-features nix-command --extra-experimental-features flakes home-manager/release-24.11 -- \
  switch --extra-experimental-features nix-command --extra-experimental-features flakes --flake ."${target}" --impure

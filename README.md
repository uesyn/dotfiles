# dotfiles

my dotfiles

## How to use

### Standalone home-manager

- Install [Nix](https://nixos.org/) with [Determinate Nix Installer](https://zero-to-nix.com/concepts/nix-installer).

```sh
# Install nix
$ curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

# Create config to use flake
$ mkdir -p ~/.config/nix
$ echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Add nix-community cache
$ nix run nixpkgs#cachix -- use nix-community
```

```sh
$ nix-shell -p git curl home-manager
$ git clone https://github.com/uesyn/dotfiles.git
$ cd ./dotfiles
$ nix --extra-experimental-features nix-command --extra-experimental-features flakes run .#hm
```

### NixOS on WSL2

After [Installation of NixOS on WSL2](https://github.com/nix-community/NixOS-WSL), run below commands.

```sh
$ nix-shell -p git curl
$ git clone https://github.com/uesyn/dotfiles
$ cd ./dotfiles
$ nixos-rebuild switch --use-remote-sudo --flake .#wsl2
```

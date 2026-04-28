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
$ nix run nixpkgs#cachix -- use numtide
```

```sh
$ nix-shell -p git curl home-manager
$ git clone https://github.com/uesyn/dotfiles.git
$ cd ./dotfiles
$ nix-shell -p git curl home-manager
$ home-manager switch --flake . --impure -b backup --show-trace
```

or init flake

```sh
$ nix-shell -p git curl home-manager
$ mkdir path/to/empty/flake/dir
$ cd path/to/empty/flake/dir
$ nix flake init -t github:uesyn/dotfiles --refresh
```

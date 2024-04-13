# dotfiles

my dotfiles

## How to use

### Standalone home-manager

- Install [Nix](https://nixos.org/) with [Determinate Nix Installer](https://zero-to-nix.com/concepts/nix-installer).

```sh
# Install nix
$ curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

# Add nix-community cache
$ nix run nixpkgs#cachix -- use nix-community
```

```sh
$ nix run home-manager -- switch --flake github:uesyn/dotfiles --impure -b backup --refresh
```

for debug

```sh
$ git clone https://github.com/uesyn/dotfiles.git
$ cd ./dotfiles
$ nix run home-manager -- switch --flake . --impure -b backup --refresh
```

### NixOS on WSL2

After [Installation of NixOS on WSL2](https://github.com/nix-community/NixOS-WSL), run below commands.

```sh
$ nix-shell -p git
$ sudo nixos-rebuild switch --flake github:uesyn/dotfiles#wsl2 --refresh
```

for debug

```sh
$ nix-shell -p git
$ git clone https://github.com/uesyn/dotfiles
$ cd dotfiles
$ sudo nixos-rebuild switch --flake .#wsl2
```

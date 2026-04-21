# dotfiles

Personal dotfiles managed by Nix/home-manager with flakes.

## Apply Config

```sh
nix --extra-experimental-features nix-command --extra-experimental-features flakes run .#hm
```

## Format

```sh
nix fmt
```

## Code Search

```sh
codesearch <query>   # wraps: opencode run --agent plan "@explorer <query>"
```

## Repo Structure

- `flake.nix` - entry point, defines apps and packages
- `home-manager/default.nix` - imports all modules
- `home-manager/<category>/default.nix` - bash, direnv, fzf, git, go, kubernetes, mise, neovim, node, opencode, python, rust, tmux, zellij, zsh
- `home-manager/opencode/skills/` - custom OpenCode skills (kubebuilder, sakura-cloud-iaas)
- `lib/` - flake utilities (forAllSystems, pkgsForSystem)

## Module Activation

- mise tools (kubectl, kubebuilder) auto-installed via `home.activation`
- zsh loads `~/.zshenv.local` if present

## OpenCode

- Provider: AI Engine (sakura.ad.jp) with Qwen3-Coder models
- Theme: Dracula
- Leader key: `ctrl+x`
- Skills bundled: `kubebuilder`, `sakura-cloud-iaas`
- Config: `opencode/opencode.jsonc`

## Git

- Pre-commit hook blocks commits to `master`, `main`, `release*`, `gh-pages`
- `ghq.root = ~/src`
- `GIT_EDITOR = nvim`

## editor

`nvim` (Neovim)

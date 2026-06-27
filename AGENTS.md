# dotfiles

Personal dotfiles managed by Nix/home-manager with flakes.

## Apply Config

There is no flake app. Use home-manager directly:

```sh
home-manager switch --flake . --impure -b backup --show-trace
```

`--impure` is required because the config reads environment variables at evaluation time.

## Format

```sh
nix fmt
```

Uses `nixfmt-tree`.

## Repo Structure

- `flake.nix` — entry point; defines `homeManagerModules.default`, `packages.homeConfigurations`, `templates`, and `formatter`.
- `home-manager/default.nix` — imports all modules.
- `home-manager/<category>/default.nix` — bash, dircolors, fence, fzf, git, go, kubernetes, mise, neovim, node, opencode, python, rust, tmux, zellij, zsh, misc.
- `home-manager/opencode/skills/` — custom OpenCode skills (`kubebuilder`, `sakura-cloud-iaas`).
- No `lib/` directory; flake utilities (`forAllSystems`) are defined inline in `flake.nix`.

## OpenCode

- Runs sandboxed via `fence`; the `opencode` shell alias is `fence <...>/bin/opencode`.
- Config generated into `~/.config/opencode/opencode.jsonc` from `home-manager/opencode/default.nix`.
- Bundled skills: `kubebuilder` (references `inputs.kubebuilder/docs`), `sakura-cloud-iaas`, `skill-creator` (from `inputs.anthropic-skills`).
- Default agent is `plan`; `autoupdate: false`; `share: disabled`.
- Env vars set: `OPENCODE_ENABLE_EXA=true`, `OPENCODE_EXPERIMENTAL_LSP_TOOL=true`.
- Providers enabled by default: `ollama-cloud`, `github-copilot`, `ai-engine`, `dynamic`.
- TUI theme: Dracula. Leader key: `ctrl+x`.

### Plugin pinning

OpenCode npm plugins must be pinned to an exact version. Configure additional plugins in `home.nix` as:

```nix
dotfiles.opencode.plugin = [
  { name = "opencode-helicone-session"; version = "2.1.0"; }
  { name = "@my-org/custom-plugin"; version = "0.5.1"; }
];
```

`home-manager` evaluates an exact-version regex on each `version` field and rejects bare names, `@latest`, `^`/`~` ranges, and dist-tags at evaluation time. The serialized spec (`name@version`) is passed through `npm-package-arg` to Bun at startup; Bun resolves to the exact version and caches it under `~/.cache/opencode/packages/<spec>/`. Default plugins (always loaded in addition to user entries) are defined inline in `home-manager/opencode/default.nix`.

### Permissions

- `opencode.jsonc` allows reading `/tmp/**` and `~/src/**`, but denies edits to both.
- `fence/base.json` blocks reads of `~/.ssh`, `~/.aws`, `~/.kube`, `~/.gnupg`, `~/.docker`, and cloud metadata APIs.
- `fence/base.json` denies remote-mutating `git`/`gh` commands, package publishing, and `sudo`.

## Git

- Pre-commit and pre-push hooks block commits/pushes to `master`, `main`, `release.*`, `gh-pages`.
- Bypass restrictions per-repo: `git-allow -y` (creates `.git/git_allow`).
- Re-enable restrictions: `git-allow -n`.
- `git-fixup` — fzf-based `git commit --fixup` for staged changes.
- `ghq.root = ~/src`.
- `GIT_EDITOR = nvim`.

## Environment Quirks

- `allowUnfree = true` is set in nixpkgs config, so unfree packages resolve without extra flags.
- `GOPATH="$HOME"` and `GOBIN="$HOME/bin"` (not `~/go`).
- Node prefix is `~/.node`; `PATH` includes `$HOME/.node/bin`.
- Mise shims path: `$HOME/.local/share/mise/shims`.
- `EDITOR = nvim`, `KUBE_EDITOR = nvim`.
- macOS-only non-Nix dependencies managed via `Brewfile` (`brew bundle`).

## Shell & Multiplexer

- zsh `dotDir` is `~/.config/zsh` and loads `~/.zshenv.local` if present.
- tmux prefix is `Ctrl+s` (not `Ctrl+b`).
- zellij leader is `Ctrl+s` entering "tmux" mode; default layout is `simple`.

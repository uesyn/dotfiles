# dotfiles

Personal dotfiles managed by Nix/home-manager with flakes.

## Apply Config

There is no flake app. Use home-manager directly:

```sh
home-manager switch --flake . --impure -b backup --show-trace
```

## Format

```sh
nix fmt
```

Uses `nixfmt-tree`.

## Code Search

```sh
codesearch <query>
```

Wraps `opencode run --agent plan "@explorer ${query}"`.

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
- Providers enabled by default: `ai-engine`, `minimax`, `github-copilot`, `opencode-go`, `dynamic`.
- AI Engine provider uses `https://api.ai.sakura.ad.jp/v1` and expects `AI_ENGINE_API_KEY`.
- Dynamic provider reads `OPENCODE_OPENAI_DYNAMIC_MODEL`, `OPENCODE_OPENAI_DYNAMIC_BASE_URL`, `OPENCODE_OPENAI_DYNAMIC_API_KEY`.
- TUI theme: Dracula. Leader key: `ctrl+x`.

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

- `GOPATH="$HOME"` and `GOBIN="$HOME/bin"` (not `~/go`).
- Node prefix is `~/.node`; `PATH` includes `$HOME/.node/bin`.
- Mise shims path: `$HOME/.local/share/mise/shims`.
- `EDITOR = nvim`, `KUBE_EDITOR = nvim`.

## Shell & Multiplexer

- zsh `dotDir` is `~/.config/zsh` and loads `~/.zshenv.local` if present.
- tmux prefix is `Ctrl+s` (not `Ctrl+b`).
- zellij leader is `Ctrl+s` entering "tmux" mode; default layout is `simple`.

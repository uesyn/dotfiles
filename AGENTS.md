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

Uses `nixfmt-tree`. Lua style is pinned in `stylua.toml` (2-space indent, double quotes, no trailing semicolons): `nix run nixpkgs#stylua -- home-manager/neovim/nvim`.

## Repo Structure

- `flake.nix` — entry point; defines `homeManagerModules.default`, `packages.homeConfigurations`, `templates`, and `formatter`.
- `home-manager/default.nix` — imports all modules.
- `home-manager/<category>/default.nix` — autoconf, bash, build-essential, copilot-language-server, dircolors, docker, fzf, git, go, javascript, kubernetes, man, mise, neovim, openssh, php, pi, pkg-config, python, rust, tmux, zellij, zsh, misc.
- `home-manager/autoconf/default.nix` — installs `autoconf` and grants the Linux outer exec gate GNU m4's directory.
- `home-manager/javascript/` (`node.nix` + `bun.nix`) — Node (npm prefix `~/.node`, nvm/fnm/pnpm homes) and Bun, plus their sandbox grants.
- `home-manager/copilot-language-server/default.nix` — installs the Copilot LSP and owns its `~/.config/github-copilot` sandbox grant.
- `home-manager/docker/default.nix` — installs the Docker client/buildx (Colima and credential helpers on macOS) and contributes their nono sandbox grants (socket, `~/.docker`, helper exec dirs).
- `home-manager/man/default.nix` — installs `man-db` on Linux and contributes its helper exec dirs (man-db/groff/gzip/zstd/util-linux).
- `home-manager/openssh/default.nix` — installs OpenSSH and grants the Linux exec gate its `libexec` helper dir (`~/.ssh` stays denied by nono's `deny_credentials`).
- `home-manager/php/default.nix` — installs phpactor and owns its config/data sandbox grants.
- `home-manager/pkg-config/default.nix` — installs `pkg-config` and points `PKG_CONFIG_PATH` at `dotfiles.buildEssential.libraries`' `.pc` dirs.
- `home-manager/mise/default.nix` — installs mise, owns its sandbox grants, exposes `dotfiles.mise.tools` for tool modules to contribute global tool versions as `lib.mkDefault` (`go` from `home-manager/go`, `kubebuilder` from `home-manager/kubernetes`, so a plain definition overrides them without `lib.mkForce`), and runs `mise install` in a `home.activation` step (after `linkGeneration`) so `home-manager switch` installs the declared tools.
- `home-manager/pi/skills/` — custom Pi skills (`kubebuilder`, `k8s-api-conventions`), generated into `~/.config/pi/skills`.
- No `lib/` directory; flake utilities (`forAllSystems`) are defined inline in `flake.nix`.

## Pi

- Extensions are wired via `home-manager/pi/default.nix` into `programs.pi-coding-agent.settings.extensions`; sources live in `home-manager/pi/extensions/`, each extension in its own directory with an `index.ts` entry point.
- `settings.defaultTools = [ "+grep" "+find" "+ls" "+codemode" "+git" ]` keeps the stock `read`/`bash`/`edit`/`write` and enables the built-in `grep`/`find`/`ls` (off by default) plus `codemode` and the extension-provided read-only `git` tool. The former custom `directory-tree.ts` extension was removed in favor of the built-in `ls`.
- `favorite-models/` (source `home-manager/pi/extensions/favorite-models/`) adds `/favorite` (`select`/`add`/`remove`/`list`) for favorite models with a per-favorite thinking level; the same model at different levels is a separate entry, Ctrl+L opens the picker, and the last selected favorite is restored at session start. State: `~/.pi/agent/favorite-models.json`.
- `git-readonly/` (source `home-manager/pi/extensions/git-readonly/`) adds a read-only `git` tool with `status`, `diff`, `log`, `show`, `branch`, `blame`, and `rev_parse` operations. It uses `spawn` with an argv array (no shell), validates revisions and paths (rejects leading `-`, `..`, absolute paths, and pathspec magic), always passes paths after `--`, rejects mutating/network operations, and runs `git` from `PATH` so nono's command policy applies. It stays enabled in plan mode.
- Skills are generated into `~/.config/pi/skills` by `home-manager/pi/default.nix` and listed in `programs.pi-coding-agent.settings.skills`: `kubebuilder` (source `home-manager/pi/skills/kubebuilder`, with `references` from `inputs.kubebuilder/docs`), `k8s-api-conventions` (source `home-manager/pi/skills/k8s-api-conventions`; distilled from the upstream kubernetes/community API conventions doc, full doc bundled as `references/api-conventions.md`), and `skill-creator` (from `inputs.anthropic-skills`). The Pi module grants `~/.config/pi` via `dotfiles.nono.filesystem.read`.
- MCP uses pi's built-in support (no `pi-mcp-adapter`, which would replace it). `home-manager/pi/default.nix` writes `~/.pi/agent/mcp.json` with the `code-review-graph` stdio server (`timeout = 120`) and the `exa` HTTP server (`timeout = 60`), both with `exposure = "direct"` so their tools are declared to the model; tool names are `mcp__<server>__<tool>`. The exa entry has no auth header (exa allows anonymous access), so no `EXA_API_KEY` is needed.

## nono

- Profile generated by `home-manager/nono/default.nix` into the fixed `~/.config/nono/profiles/agents.json`; options: `dotfiles.nono.{aliasPrefix,wrap,filesystem.<read|readFile|allow|allowFile|unixSocket|deny|bypassProtection>,commandPolicies.<executableDirs|commands>}`. The `filesystem.*`, `commandPolicies.executableDirs` and `commandPolicies.commands` (each command value is a function of `pkgs`) are public extension points: the nono module defines the core policy through the same options and tool modules append entries by setting them (list options concatenate). The core keeps only agent-workspace/scratch paths (`~/bin`, `~/pkg`, `~/src`, `/tmp`, `~/.cache`, `~/.local/state/{home-manager,nix}`) and the unowned Nix config (`~/.config/nix`); each tool's module contributes its own config/data/state dirs (`bash`, `docker`, `git`, `go`, `javascript`, `kubernetes`, `man`, `mise`, `neovim`, `openssh`, `pi`, `python`, `rust`, `zsh`); `dotfiles.nono.wrap` (the aliased commands) is likewise module-contributed (Pi).
- `command_policies` gives `gh` and `git` child sandboxes. `gh` is `default = "deny"` with a read-only allowlist (`ghAllowRules`); subcommand paths must come first (`gh repo list -R owner/repo`), leading flags are denied, and `contains` is avoided because another command's arguments could satisfy it (`gh api -f repo list`). `git` is `default = "allow"` with a short `deny` list (`gitDenyRules`: `push`, `fetch`, `pull`, `ls-remote`, `remote add|remove|rm|set-url|prune|update`, `submodule add|update`), so local operations (commits, rebases, `git stash push`) run freely; prefix matching starts at the first argument, so a leading global option (`git -c x=y push`) bypasses the deny, while the sandbox's network block still prevents network remotes. The `git` caller edge uses `gitChildSandbox` (no worktree write access) so `git gc` children never touch the real repo, with the same deny list plus clone. `gh` chains to `git` via `can_use` + the `gh` caller edge for repo detection; `gh repo clone` / `gh pr checkout` / `gh gist clone` are intentionally not allowed because they need git write operations. `ghSandbox` has `network.allow_all`. Git's normal edge sandboxes leave `network` unset and stay offline. A `commands.git.intercept` rule with `match.argv.prefix = [ "clone" ]` and `action.type = "passthrough"` replaces the selected sandbox only for clone: it grants network access, writes to the live cwd and `/tmp`, CA bundle reads, and execution of `${pkgs.git}/libexec/git-core` helpers. It does not use `@git:toplevel`, so clone works outside an existing repo; destinations outside cwd and `/tmp` need explicit grants. Leading global flags (`git -c ... clone`) do not select this networked sandbox. The `git` caller edge additionally denies clone before interception, so nested shim-mediated clones cannot select the override. Clone's trusted helpers can inherit its network/write permissions; this is not a remote-read-only security guarantee against arbitrary Git config/options. These gh/git command policies live in the nono module's `commands/` submodule (`home-manager/nono/commands/{default,gh,git}.nix`), deliberately kept there rather than in tool modules (they are the agent's main guardrails and the git sandbox is a single security unit).
- Sandbox details: the session profile includes only the `nix_runtime` group (`/nix/store`, nix profile paths) instead of a blanket read grant on all of `/nix`; the per-toolchain `*_runtime` / `mise_manager` groups were dropped because the owning modules grant the runtime homes (mise, cargo/rustup, npm/node/nvm/fnm/pnpm, bun, pyenv/uv/conda, `~/.local/lib`) via `dotfiles.nono.filesystem.allow` for installs and the Tool Sandbox execute grant; the `~/.cargo/credentials*` denies are gone because the rust module's `~/.cargo` allow would otherwise sit above them (Linux rejects deny-under-allow); the child sandboxes grant `/nix/store`, which also covers home-manager files that are symlinks into the store. `fs_read` grants read below a path (files included). `gh` also gets `fs_write` for downloads and `network.allow_all`, and nixpkgs' `gh` wrapper needs the pinned `executable` (`${pkgs.gh}/bin/.gh-wrapped`); the `git` sandbox grants `fs_write` on `@git:toplevel` so allowed write commands can update the worktree. Docker access is granted through `filesystem.unix_socket` (`/var/run/docker.sock` on Linux; the Colima sockets `~/.colima/docker.sock`, `~/.colima/default/docker.sock`, and `~/.config/colima/docker.sock` on macOS) and `~/.docker` via `filesystem.allow`/`filesystem.bypass_protection`; `home-manager/docker/default.nix` sets these through `dotfiles.nono.filesystem.{unixSocket,allow,bypassProtection}`.
- Tool Sandbox activation rebuilds the outer session's execute grant from executables found by scanning non-writable `PATH` directories (plus their shared-library closure). Nix wrapper scripts also get their `exec` target added, but other PATH-external store binaries are denied with `EACCES`, so nixpkgs Go (`$GOROOT/pkg/tool/*`), flake formatters (`nix fmt` -> `treefmt`) and hardcoded store paths in shell init fail inside the sandbox; toolchains that re-exec PATH-external helpers either live under writable grants (mise, `~/.local/share/mise`) or list their helper directory via `command_policies.executable_dirs` (the openssh module adds OpenSSH's `libexec`; the man module adds man-db's `libexec/man-db` plus its wrapped groff/util-linux/gzip/zstd dirs, and the Docker module adds docker-client's `libexec/docker` and docker-compose's `libexec/docker/cli-plugins` for `docker compose`, all via `dotfiles.nono.commandPolicies.executableDirs`).

## build-essential

- `home-manager/build-essential/` (`gcc.nix` + `make.nix`). `gcc.nix` builds a stable runtime prefix (fixed at `~/.local/nix-runtime`) so that ELF files produced by the Nix-managed GCC reference the prefix instead of `/nix/store/<hash>` paths. It is always enabled on Linux; non-Linux platforms use the stock `pkgs.gcc`. It replaces `pkgs.gcc` in `home.packages` (both provide `bin/gcc`).
- The prefix is one Home Manager `home.file` symlink to a single store derivation (`nix-runtime-<gcc-version>`), swapped atomically on update/rollback and rooted against GC. The tree symlinks `${pkgs.glibc}/lib` (loader, libc, `crt*.o`, `libc.so` script), `${pkgs.glibc}/lib64` when present (the multiarch loader objects), `${lib.getLib pkgs.gcc-unwrapped}/lib` (`libgcc_s`, `libstdc++`), and `${lib.getDev pkgs.glibc}/include`; `dotfiles.buildEssential.libraries` adds more packages' `lib`/`include`.
- `gcc` / `cc` / `g++` / `c++` are `writeShellScriptBin` wrappers around `pkgs.gcc-unwrapped` that pass `-B$RUNTIME/{lib,gcc-lib}/`, `-B${pkgs.binutils-unwrapped}/bin/`, `-isystem $RUNTIME/include`, `-L$RUNTIME/{gcc-lib,lib}`, `-Wl,-rpath,$RUNTIME/{gcc-lib,lib}` and `-Wl,--dynamic-linker=$RUNTIME/lib/ld-linux-*.so*`, so `readelf`/`strings` show no store path; the `-B` on `binutils-unwrapped` pins the raw `as`/`ld` regardless of `PATH` order (the wrapped `pkgs.binutils` `ld` would inject store paths into RUNPATH). `cpp`, `gcc-ar`, `gcc-nm`, and `gcc-ranlib` are plain wrappers; `pkgs.binutils-unwrapped` is installed so `as` / `ld` resolve to raw Nix binutils on `PATH`.
- Under nono the module adds the prefix to `dotfiles.nono.filesystem.read` and `$RUNTIME/lib` to `dotfiles.nono.commandPolicies.executableDirs`; the prefix must stay non-writable (a read grant, not `filesystem.allow`) so `validate_trusted_executable_dirs` accepts it and the agent cannot swap the loader. The build side still needs GCC's `libexec` helpers, which the module grants via `dotfiles.nono.commandPolicies.executableDirs`.
- `make.nix` installs `pkgs.gnumake`.

## Git

- Pre-commit and pre-push hooks block commits/pushes to `master`, `main`, `release.*`, `gh-pages`.
- Bypass restrictions per-repo: `git-allow -y` (creates `.git/git_allow`).
- Re-enable restrictions: `git-allow -n`.
- `git-fixup` — fzf-based `git commit --fixup` for staged changes.
- `ghq.root = ~/src`.
- `GIT_EDITOR = nvim`.

## Neovim

- `home-manager/neovim/default.nix` installs Neovim, lists the plugins and holds the whole `init.lua` (a `require` list only). home-manager generates `~/.config/nvim/init.lua`, so the repo tree `nvim/` must not contain one.
- `nvim/lua/config/` — one file per concern: `option` (grouped `vim.opt.*` settings), `keymap` (global maps), `autocmd` (yank → OSC52 clipboard), `lsp` (diagnostics, `LspAttach` keymap table, completion popup border, `LspProgress` echo, `vim.lsp.enable` list), `copilot` (sign-in command, inline completion), `statusline` (`_G.statusline`, the config's only global, referenced as `%!v:lua.statusline()`).
- `nvim/lsp/<server>.lua` — declarative server config (a returned table, no side effects), loaded by name from `vim.lsp.enable`.
- `nvim/lua/plugins/<plugin>.lua` — one lz.n spec per plugin; `after` does `setup` and sets that plugin's keymaps. `keys`/`ft`/`event` are load triggers only (`keys` replays the key after `after` runs), which is why a plugin key can appear both as a trigger and as a real mapping.
- `nvim/lua/util.lua` — shared helpers (`temp_buffer_keymaps` for quickfix/blame-style read-only windows).
- Rules: `vim.opt.*` (never `vim.opt["x"]`), `vim.opt_local.*` in `ftplugin/`; double quotes, 2-space indent, no trailing semicolons (`stylua.toml`); `local` everywhere (`_G` only for the statusline); every keymap carries `desc`; comments explain *why*, with `-- ref:` URLs for upstream workarounds.
- Lazy-loaded plugins are declared with `optional = true` in `programs.neovim.plugins` (`map (plugin: { inherit plugin; optional = true; }) lazyPlugins`) so home-manager keeps them out of the startup packpath.

## Environment Quirks

- `allowUnfree = true` is set in nixpkgs config, so unfree packages resolve without extra flags.
- `GOPATH="$HOME"` and `GOBIN="$HOME/bin"` (not `~/go`).
- Go itself is mise-managed via `dotfiles.mise.tools` (`home-manager/go` sets `tools.go`); `kubebuilder` is likewise a mise tool, added by `home-manager/kubernetes`. Only `gopls` stays in Nix. nixpkgs Go re-execs helpers from `$GOROOT/pkg/tool`, which the nono Tool Sandbox's PATH-scan exec allowlist denies (`go tool compile: ... permission denied`), while mise installs under the writable `~/.local/share/mise`.
- Node prefix is `~/.node`; `PATH` includes `$HOME/.node/bin`.
- Mise shims path: `$HOME/.local/share/mise/shims`.
- `EDITOR = nvim`, `KUBE_EDITOR = nvim`.
- macOS-only non-Nix dependencies managed via `Brewfile` (`brew bundle`).

## Shell & Multiplexer

- zsh `dotDir` is `~/.config/zsh` and loads `~/.zshenv.local` if present.
- tmux prefix is `Ctrl+s` (not `Ctrl+b`).
- zellij leader is `Ctrl+s` entering `locked` mode (toggle back with `Ctrl+s`); the built-in default layout is used.

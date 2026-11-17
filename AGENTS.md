# dotfiles

Personal dotfiles: Nix + home-manager flakes.

## Apply & Format

```sh
home-manager switch --flake . --impure -b backup --show-trace   # --impure: eval reads env vars
nix fmt                                                        # nixfmt-tree
nix run nixpkgs#stylua -- home-manager/neovim/nvim              # Lua: stylua.toml
```

## Layout

- `flake.nix` — `homeManagerModules.default`, `packages.homeConfigurations`, `templates`, `formatter`; utilities (`forAllSystems`) inline.
- `home-manager/default.nix` imports one module per tool. A tool module installs the tool and owns its nono grants (`filesystem.*`, `commandPolicies.executableDirs`); the nono module holds only core policy.
- `home-manager/pi/` — Pi module, `extensions/`, `skills/`. `home-manager/build-essential/` — `gcc.nix`, `make.nix`. `home-manager/nono/` — profile + `commands/`.

## Pi

- Extensions: `home-manager/pi/extensions/<name>/index.ts`, wired via `settings.extensions`. The tree is copied into one store directory (`~/.local/share/pi/extensions` links to it) so sibling imports resolve.
- `settings.defaultTools = [ "+grep" "+find" "+ls" "+codemode" "+git" "+gh" "+ast_grep" "+subagent" ]` — stock `read`/`bash`/`edit`/`write` plus built-in `grep`/`find`/`ls`, codemode, read-only `git`, structural `ast_grep`, `subagent`.
- `bash-sandbox/`: overrides only `bash` (incl. codemode) and `!`/`!!` by swapping `shellPath` to the `nono-bash` wrapper (`dotfiles.pi.sandbox.profile`). The wrapper path is baked into `endpoint.ts` at build time, so no config or env is read and project settings cannot pick the shell. The wrapper unsets `NONO_*`/node/bash init env and `exec`s `nono run -s --profile <profile> --allow-cwd --workdir "$PWD" --no-rollback --no-audit --no-diagnostics -- <nix bash> "$@"`; Pi keeps spawn, timeout, process-group kill and cleanup. `write`/`edit`/`read`/MCP stay unsandboxed; no nested-run support. `/sandbox [on|off]` toggles (OFF needs idle Pi, no confirmation, not persisted). A missing or non-executable wrapper fails closed; a new wrapper needs a Pi restart. Plan mode blocks `bash` itself, `!`/`!!` stay sandboxed. See its README.
- `favorite-models/`: `/favorite` (pick), `/favorite add|remove|list`, per-favorite thinking level; state `~/.pi/agent/favorite-models.json`. Presets only — it records nothing about what was used last.
- `last-model/`: records the model + thinking level on every `model_select`/`thinking_level_select` into `~/.pi/agent/last-model.json` (`PI_LAST_MODEL_FILE`) and applies it on `session_start` for `startup`/`new` only, unless the invocation pinned one with `--model`/`--models`/`--thinking`; `resume`/`fork` keep the session's own model and `reload` keeps the running one. Selecting a favorite is recorded here too, so `favorite-models` needs no "last selected" state. Tests: `node --test --import ./tests/register.mjs "tests/*.test.ts"` with `PI_TEST_PACKAGE_DIR`.
- `subagent/`: model-only `subagent` tool with fixed read-only `scout`/`planner`/`reviewer` roles, two-slot queue, cancelled by plan mode and shutdown. See its README.
- `gh-readonly/`: read-only `gh` tool for repository, PR and issue views/lists; fixed commands, no arbitrary flags; the Nix-managed gh executable path is baked in at build time, and `GH_HOST` selects GHE before Pi starts. See its README.
- `git-readonly/`: read-only `git` tool (`status`, `diff`, `log`, `show`, `branch`, `blame`, `rev_parse`), Nix-managed executable path baked in at build time, argv spawn, validated revs/paths, `--` before paths; stays enabled in plan mode. Pi runs outside nono, so the tool's allowlist is not a sandbox.
- `ast-grep/`: read-only structural search `ast_grep` (`search` pattern/node kind, `rule` inline YAML via `scan --inline-rules`, `debug` `--debug-query` + `--stdin`), streamed `--json=stream` sorted into `path:line:col` text, validated paths/globs, no rewrite flag ever, and every call pins `-c <empty config>` + `--custom-languages ignore` so a repo's `sgconfig.yml` (or an ancestor's) cannot remap languages or `dlopen` a native custom-language library; enabled in plan mode and shared with subagents. See its README.
- Skills: `settings.skills` → `~/.config/pi/skills` — `kubebuilder` (+ upstream docs), `k8s-api-conventions`, `skill-creator`.
- `pi-web`: browser UI for pi ([agegr/pi-web](https://github.com/agegr/pi-web)), installed from npm by mise (`dotfiles.mise.tools."npm:@agegr/pi-web" = lib.mkDefault "0.17.0"`; the npm backend needs `npm` from the javascript module). The backend's install directory is writable, which pi-web needs: it rewrites `.next/prerender-manifest.json` on every start so the `previewModeId` published in the package cannot bypass its password gate (Next skips middleware for `x-prerender-revalidate` requests). Shares `~/.pi/agent` with pi, so sessions, models and extensions (bash-sandbox included) apply.
- `pi-web-tailcat` (`pi-web-tailcat.nix` + `pi-web-tailcat.sh`): one command per side. `serve` starts pi-web when it is not running — with `PI_WEB_ALLOWED_HOSTS=server.tailcat`, the name tailcat's SOCKS proxy dials and the only one a browser can send, since tailcat addresses are case-sensitive and browser hostnames are not — refuses an already running pi-web that answers 403 to that Host, then runs `tailcat serve <port>` and saves the address to `~/.cache/tailcat/pi-web-<port>.addr`; `connect` execs `tailcat socks` for it. Plain HTTP/1.1 inside the WireGuard tunnel: no TLS, no secure context (no web push/service worker), no h2. One listener per saved key (`--key`, default `default`; two tunnels on one key fight for the address), `--allow` passes client node keys. `PI_WEB_PASSWORD`/`--password-file` is optional: without a password pi-web runs unauthenticated and the command warns that the address is then the only credential. Run it outside nono, because pi-web writes `~/.pi/agent` (sessions, run records).
- MCP: built-in support. `~/.pi/agent/mcp.json` declares `exa` (HTTP, 60s, `exposure = "direct"`); tool names `mcp__<server>__<tool>`.

## nono

- Profile `~/.config/nono/profiles/agents.json` from `home-manager/nono/default.nix`. Options `dotfiles.nono.{aliasPrefix,wrap,filesystem.*,commandPolicies.*}` are the extension points (list options concatenate; each command value is a `pkgs` function). `wrap` creates shell aliases; Pi uses none.
- Core grants: `~/bin`, `~/pkg`, `~/src`, `/tmp`, `~/.cache`, `~/.local/state/{home-manager,nix}`, `~/.config/nix`, plus the `nix_runtime` group. Runtime homes come from their own modules via `filesystem.allow`. A deny cannot sit under a grant (Linux rejects deny-under-allow), so `~/.cargo` has no credentials deny.
- `commands/` (`{default,gh,git}.nix`) holds the gh/git child sandboxes as one security unit. `gh`: deny by default with a read-only allowlist, subcommand path first, no leading flags, `fs_write` + `network.allow_all`, pinned `${pkgs.gh}/bin/.gh-wrapped`. `git`: allow with a short deny list (`push`, `fetch`, `pull`, `ls-remote`, `remote add|remove|rm|set-url|prune|update`, `submodule add|update`); a leading global flag bypasses it and the sandbox is offline. Local writes are `@git:toplevel` plus `@git:common-dir` (a worktree's `.git` is a file into the main repository, so commits there write objects/refs/logs outside the checkout) and reads add `@git:config-files` (global config and its `include.path` targets, which `git` fatals on when unreadable); git's own children get the same reads without the writes, so hooks that shell out to `git` work. The git sandbox also takes `exec_paths` from `commandPolicies.gitExecPaths`: `git` execs hooks inside its own command sandbox, whose execute allowlist does not include the session's `executable_dirs` scan. Clone is the only intercepted command: networked passthrough with cwd/`/tmp` writes, CA reads and `libexec/git-core` exec, not `@git:toplevel` (works outside a repo); leading global flags skip it and the caller edge denies clone.
- Exec gate: rebuilt per activation by scanning non-writable `PATH` dirs (+ lib closure); other store binaries are denied with `EACCES`, so `$GOROOT/pkg/tool`, `nix fmt`→`treefmt` and hardcoded store paths fail inside. Tools that re-exec helpers either live under writable grants (mise) or add their helper dir via `commandPolicies.executableDirs` (openssh `libexec`, man, docker compose plugins, git's hooks linkFarm).
- Docker: `unix_socket` (`/var/run/docker.sock`; Colima sockets on macOS) plus `~/.docker` allow/bypass.

## build-essential

- `gcc.nix`: ELF output references `~/.local/nix-runtime` (one `home.file` symlink to a store derivation, GC-rooted) instead of `/nix/store/<hash>`; tree = glibc lib/lib64/include, gcc-unwrapped lib, `dotfiles.buildEssential.libraries`.
- `gcc`/`cc`/`g++`/`c++` wrap `pkgs.gcc-unwrapped` with `-B$RUNTIME/{lib,gcc-lib}/`, `-B${pkgs.binutils-unwrapped}/bin/` (raw `as`/`ld`, else RUNPATH gets store paths), `-isystem`, `-L`, `-rpath`, `--dynamic-linker`. `cpp`/`gcc-ar`/`gcc-nm`/`gcc-ranlib` are plain wrappers; `binutils-unwrapped` is installed.
- nono: prefix in `filesystem.read` (must stay non-writable so the exec gate trusts it), `$RUNTIME/lib` and GCC `libexec` in `commandPolicies.executableDirs`.
- `make.nix`: `gnumake`.

## Git

- Hooks block commits/pushes to `master`, `main`, `release.*`, `gh-pages`; per-repo bypass `git-allow -y`, re-enable `git-allow -n`. The marker is `${git rev-parse --path-format=absolute --git-common-dir}/git_allow`, not `<toplevel>/.git/git_allow`, so a linked worktree (where `.git` is a file) shares the repository marker. Hooks are built with `patchShebangs` to use Nix Bash. Home-manager links them into a store linkFarm at `core.hooksPath`; Linux exec grants include the linkFarm and Bash directories in `commandPolicies.executableDirs`, and the hook targets and Bash executable in `commandPolicies.gitExecPaths`.
- `git-fixup`: fzf `git commit --fixup` for staged changes. `ghq.root = ~/src`. `GIT_EDITOR = nvim`.

## Neovim

- `home-manager/neovim/default.nix` installs Neovim, lists plugins and holds `init.lua` (a `require` list); HM generates `~/.config/nvim/init.lua`, so `nvim/` has none.
- `nvim/lua/config/`: `option`, `keymap`, `autocmd` (yank→OSC52), `lsp`, `copilot`, `statusline` (`_G.statusline`, `%!v:lua.statusline()`). `nvim/lsp/<server>.lua`: declarative table. `nvim/lua/plugins/<plugin>.lua`: one lz.n spec, `after` sets up + keymaps, `keys`/`ft`/`event` are triggers only. `nvim/lua/util.lua`: helpers.
- Rules: `vim.opt.*` (`vim.opt_local.*` in `ftplugin/`), `local` everywhere (`_G` only for the statusline), every keymap has `desc`, comments explain why with `-- ref:` links. Lazy plugins use `optional = true` in `programs.neovim.plugins`.

## Rules & Quirks

- Public repo: no absolute home paths, usernames, hostnames, emails or credentials; use `~`/relative paths and resolve machine paths at runtime (`tmpdir()`, `homedir()`, `process.execPath`).
- `allowUnfree = true`. `GOPATH=$HOME`, `GOBIN=$HOME/bin`. Go, kubebuilder and pi-web are mise tools (`dotfiles.mise.tools` as `lib.mkDefault`, `mise install` on switch); only `gopls` is in Nix, because nixpkgs Go re-execs `$GOROOT/pkg/tool` which the exec gate denies. Node prefix `~/.node` (+ `$HOME/.node/bin`), mise shims `~/.local/share/mise/shims`. `EDITOR`/`KUBE_EDITOR = nvim`. macOS extras via `Brewfile`.
- zsh `dotDir = ~/.config/zsh` (+ `~/.zshenv.local`). tmux prefix `Ctrl+s`. zellij leader `Ctrl+s` → `locked` (default layout).

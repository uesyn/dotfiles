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
- `home-manager/<category>/default.nix` — autoconf, bash, build-essential, copilot-language-server, dircolors, docker, fence, fzf, git, go, javascript, kubernetes, man, mise, neovim, opencode, openssh, php, pi, pkg-config, python, rust, tmux, zellij, zsh, misc.
- `home-manager/autoconf/default.nix` — installs `autoconf` and grants the Linux outer exec gate GNU m4's directory.
- `home-manager/javascript/` (`node.nix` + `bun.nix`) — Node (npm prefix `~/.node`, nvm/fnm/pnpm homes) and Bun, plus their sandbox grants.
- `home-manager/copilot-language-server/default.nix` — installs the Copilot LSP and owns its `~/.config/github-copilot` sandbox grant.
- `home-manager/docker/default.nix` — installs the Docker client/buildx (Colima and credential helpers on macOS) and contributes their nono sandbox grants (socket, `~/.docker`, helper exec dirs).
- `home-manager/man/default.nix` — installs `man-db` on Linux and contributes its helper exec dirs (man-db/groff/gzip/zstd/util-linux).
- `home-manager/openssh/default.nix` — installs OpenSSH and grants the Linux exec gate its `libexec` helper dir (`~/.ssh` stays denied by nono's `deny_credentials`).
- `home-manager/php/default.nix` — installs phpactor and owns its config/data sandbox grants.
- `home-manager/pkg-config/default.nix` — installs `pkg-config` and points `PKG_CONFIG_PATH` at `dotfiles.buildEssential.libraries`' `.pc` dirs.
- `home-manager/mise/default.nix` — installs mise, owns its sandbox grants, exposes `dotfiles.mise.tools` for tool modules to contribute global tool versions as `lib.mkDefault` (`go` from `home-manager/go`, `kubebuilder` from `home-manager/kubernetes`, so a plain definition overrides them without `lib.mkForce`), and runs `mise install` in a `home.activation` step (after `linkGeneration`) so `home-manager switch` installs the declared tools.
- `home-manager/opencode/skills/` — custom OpenCode skills (`kubebuilder`, `sakura-cloud-iaas`).
- `home-manager/pi/extensions/undo/` — git-backed pi extension providing `/undo` `/redo` `/undo-purge` for agent runs (conversation rewind + file snapshot restore). See its README.
- No `lib/` directory; flake utilities (`forAllSystems`) are defined inline in `flake.nix`.

## Pi

- Extensions are wired via `home-manager/pi/default.nix` into `programs.pi-coding-agent.settings.extensions`; sources live in `home-manager/pi/extensions/`.
- `pi-undo` (source `home-manager/pi/extensions/undo/`) adds `/undo`, `/redo`, `/undo-purge` to pi. Snapshots are git trees in a private gitdir per worktree under `~/.pi/agent/undo/git/<sha1(worktree)>/`, pinned with `refs/pi-undo/<sessionId>/<i>` and tracked in `registry.json`; config in `~/.pi/agent/undo.json` or `.pi/undo.json`. Git is always invoked subcommand-first (repo selected through `GIT_DIR`/`GIT_WORK_TREE`, cwd via spawn options) to stay compatible with the nono git policy. Tests: `bun test home-manager/pi/extensions/undo/test/`.
- `favorite-models.ts` adds `/favorite` (`select`/`add`/`remove`/`list`) for favorite models with a per-favorite thinking level; the same model at different levels is a separate entry, Ctrl+L opens the picker, and the last selected favorite is restored at session start. State: `~/.pi/agent/favorite-models.json`.

## OpenCode

- The `opencode` / `pi` shell aliases run the nono wrapper (`nono run --profile agents -s --allow-cwd -- <cmd>`); use `fence-opencode` / `fence-pi` for the fence wrappers (`dotfiles.fence.aliasPrefix`).
- Config generated into `~/.config/opencode/opencode.jsonc` from `home-manager/opencode/default.nix`.
- Bundled skills: `kubebuilder` (references `inputs.kubebuilder/docs`), `sakura-cloud-iaas`, `skill-creator` (from `inputs.anthropic-skills`).
- Default agent is `plan`; `autoupdate: false`; `share: disabled`.
- Env vars set: `OPENCODE_ENABLE_EXA=true`, `OPENCODE_EXPERIMENTAL_LSP_TOOL=true`.
- Providers enabled by default: `ollama-cloud`, `github-copilot`, `ai-engine`, `dynamic`.
- TUI theme: Dracula. Leader key: `ctrl+x`.

### OpenCode plugins

Configure additional OpenCode plugins in `home.nix` using any plugin format supported by OpenCode:

```nix
dotfiles.opencode.plugin = [
  "opencode-helicone-session"
  "opencode-helicone-session@2.1.0"
  "@my-org/custom-plugin@next"
  "./plugins/my-plugin.ts"
  "file:///absolute/path/plugin.js"
  [ "opencode-bar" { key = "value"; } ]
];
```

Entries are serialized to `opencode.jsonc` unchanged. The Nix option accepts JSON-compatible values; OpenCode validates the plugin format at startup. Default plugins (always loaded in addition to user entries) are defined inline in `home-manager/opencode/default.nix`.

### Permissions

- `opencode.jsonc` allows reading `/tmp/**` and `~/src/**`, but denies edits to both.
- `fence.json` blocks reads of `~/.ssh`, `~/.aws`, `~/.kube`, `~/.gnupg`, `~/.docker`, and cloud metadata APIs.
- `fence.json` denies remote-mutating `git`/`gh` commands, package publishing, and `sudo`.
- `fence` and `nono` are intentionally independent sandboxes with separate config sources; where both happen to list the same path (e.g. the Docker/Colima sockets, `~/.docker`), the duplication is deliberate — do not factor them into a shared option.

## nono

- Profile generated by `home-manager/nono/default.nix` into the fixed `~/.config/nono/profiles/agents.json`; options: `dotfiles.nono.{aliasPrefix,wrap,filesystem.<read|readFile|allow|allowFile|unixSocket|deny|bypassProtection>,commandPolicies.<executableDirs|commands>}`. The `filesystem.*`, `commandPolicies.executableDirs` and `commandPolicies.commands` (each command value is a function of `pkgs`) are public extension points: the nono module defines the core policy through the same options and tool modules append entries by setting them (list options concatenate). The core keeps only agent-workspace/scratch paths (`~/bin`, `~/pkg`, `~/src`, `/tmp`, `~/.cache`, `~/.local/state/{home-manager,nix}`) and the unowned Nix config (`~/.config/nix`); each tool's module contributes its own config/data/state dirs (`bash`, `docker`, `git`, `go`, `javascript`, `kubernetes`, `man`, `mise`, `neovim`, `opencode`, `openssh`, `pi`, `python`, `rust`, `zsh`); `dotfiles.nono.wrap` (the aliased commands) is likewise module-contributed (OpenCode/Pi).
- `command_policies` gives `gh` and `git` child sandboxes. `gh` is `default = "deny"` with a read-only allowlist (`ghAllowRules`); subcommand paths must come first (`gh repo list -R owner/repo`), leading flags are denied, and `contains` is avoided because another command's arguments could satisfy it (`gh api -f repo list`). `git` is `default = "allow"` with a short `deny` list (`gitDenyRules`: `push`, `fetch`, `pull`, `clone`, `ls-remote`, `remote add|remove|rm|set-url|prune|update`, `submodule add|update`), so local operations (commits, rebases, the pi-undo plumbing, `git stash push`) run freely; prefix matching starts at the first argument, so a leading global option (`git -c x=y push`) bypasses the deny, while the sandbox's network block still prevents network remotes. The `git` caller edge uses `gitChildSandbox` (private store only, no worktree) so `git gc` children never touch the real repo, with the same deny list. `command_policies.session_export_env` and `commands.git.export_env` forward `GIT_DIR`/`GIT_WORK_TREE` (the tool sandbox strips `GIT_*`), which is how pi-undo selects its private repo without global flags. `gh` chains to `git` via `can_use` + the `gh` caller edge for repo detection; `gh repo clone` / `gh pr checkout` / `gh gist clone` are intentionally not allowed because they need git write operations. `ghSandbox` is the only command sandbox with `network.allow_all`; the git sandboxes leave `network` unset, so Tool Sandbox's default network block keeps git offline. These gh/git command policies live in the nono module's `commands/` submodule (`home-manager/nono/commands/{default,gh,git}.nix`), deliberately kept there rather than in tool modules (they are the agent's main guardrails and the git sandbox is a single security unit); `~/.pi/agent/undo` is granted inside the git sandbox because pi-undo runs git there, not from the pi module.
- Sandbox details: the session profile includes only the `nix_runtime` group (`/nix/store`, nix profile paths) instead of a blanket read grant on all of `/nix`; the per-toolchain `*_runtime` / `mise_manager` groups were dropped because the owning modules grant the runtime homes (mise, cargo/rustup, npm/node/nvm/fnm/pnpm, bun, pyenv/uv/conda, `~/.local/lib`) via `dotfiles.nono.filesystem.allow` for installs and the Tool Sandbox execute grant; the `~/.cargo/credentials*` denies are gone because the rust module's `~/.cargo` allow would otherwise sit above them (Linux rejects deny-under-allow); the child sandboxes grant `/nix/store`, which also covers home-manager files that are symlinks into the store. `fs_read` grants read below a path (files included). `gh` also gets `fs_write` for downloads and `network.allow_all`, and nixpkgs' `gh` wrapper needs the pinned `executable` (`${pkgs.gh}/bin/.gh-wrapped`); the `git` sandbox grants `fs_write` on `@git:toplevel` and `~/.pi/agent/undo` (pi-undo's private gitdir) so allowed write commands can update the worktree and snapshot store, while `gitChildSandbox` (caller `git`) is limited to `~/.pi/agent/undo`. Docker access is granted through `filesystem.unix_socket` (`/var/run/docker.sock` on Linux; the Colima sockets `~/.colima/docker.sock`, `~/.colima/default/docker.sock`, and `~/.config/colima/docker.sock` on macOS, the same paths `fence` lists independently) and `~/.docker` via `filesystem.allow`/`filesystem.bypass_protection`; `home-manager/docker/default.nix` sets these through `dotfiles.nono.filesystem.{unixSocket,allow,bypassProtection}`.
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
- zellij leader is `Ctrl+s` entering "tmux" mode; default layout is `simple`.

# dotfiles

Personal dotfiles: Nix + home-manager flakes, public repository.

## Commands

These run inside the Pi bash sandbox.

```sh
# Extension tests, from home-manager/pi/extensions.
PI_TEST_PACKAGE_DIR=<installed pi package> node --test --import ./tests/register.mjs "*/tests/*.test.ts"

# Evaluate a flake attribute, or plan the build of one.
nix --extra-experimental-features 'nix-command flakes' eval .#formatter.x86_64-linux
nix --extra-experimental-features 'nix-command flakes' build .#pi-web --dry-run
```

`nix` needs the flag inside the sandbox. `tests/register.mjs` is the only
copy of the peer-module resolver, and it stays out of the store tree Pi loads.

These need the user, because the exec gate denies store binaries and store
writes.

```sh
home-manager switch --flake . --impure -b backup --show-trace   # --impure: eval reads env vars
nix fmt                                                         # nixfmt-tree
nix run nixpkgs#stylua -- home-manager/neovim/nvim               # Lua
```

## Validation

- Nix change: evaluate or dry-run the attribute you touched, then ask the user
  to run `home-manager switch`.
- Pi extension change: run the extension tests above, which run in the sandbox.
- Lua change: ask the user to run the stylua command above.

## Rules

- Never write an absolute home path, a username, a hostname, an email or a
  credential. Use `~` or a relative path, and resolve a machine path at runtime
  with `tmpdir()`, `homedir()` or `process.execPath`.
- Keep one directory per tool under `home-manager/`. The module that installs a
  tool owns that tool's nono grants (`dotfiles.nono.filesystem.*`,
  `dotfiles.nono.commandPolicies.*`), and `home-manager/nono/` holds core
  policy only.
- Register a Pi skill as an `xdg.configFile."pi/skills/<name>"` entry in
  `home-manager/pi/default.nix`. A directory added under `pi/skills/` alone is
  not installed.
- Keep this file to rules an agent cannot read off the code. Implementation
  detail belongs in the module's comments or its README.

## Pi

- An extension is `home-manager/pi/extensions/<name>/index.ts`, wired through
  `settings.extensions`. The whole tree is copied into one store directory that
  `~/.local/share/pi/extensions` links to, so imports between extensions
  resolve.
- `bash` (codemode's too) and `!`/`!!` run inside nono. `write`, `edit`, `read`,
  `grep`, `find`, `ls` and MCP run directly as Pi. Nested `nono run` does not
  work. See `home-manager/pi/extensions/bash-sandbox/README.md`.
- Delegate with the pstack `agent` tool. Run `git`, `gh` and `ast-grep` through
  the sandboxed `bash` tool.
- `mutableSettings = true` merges the declared settings into a writable
  `settings.json` on `home-manager switch`, not at launch, so stop Pi and
  pi-web before you switch. A declared value wins and nested objects merge, but
  a declared array replaces the saved array, except `packages`, which merges by
  package identity. Removing a declaration leaves its saved value. Pi saves the
  model and thinking preferences there too.
- `home-manager/pi/context.md` is the default for
  `programs.pi-coding-agent.context` (`lib.mkDefault`). It installs as
  `~/.pi/agent/AGENTS.md`, which loads in every working directory. Rules for
  this repository stay in this file.
- Pi resolves an extension's `@earendil-works/pi-ai` to
  `dist/core/extensions/pi-ai-extension-view.{js,d.ts}`, not to the package
  root. That view's `StringEnum` returns `TUnsafe`, so
  `Static<typeof StringEnum(...)>` is a literal union.
- A theme is one file in `home-manager/pi/themes/`, and its file name must
  equal the theme `name` because Pi hot-reloads by that path. See its README.
- `pi-web` is built with `nix build .#pi-web` and pinned in `flake.lock`. Update
  it in Nix, never with `pi-web update`. Each server keeps a private Next.js
  directory under `~/.local/state/pi-web/runtime/` and aborts startup when it
  cannot rotate the preview secrets there. A normal shutdown removes it, so
  delete a leftover directory after a forced stop only once no server uses it.
- `pi-web-tailcat` tunnels pi-web on Linux, with `start` and `stop` only. Run it
  outside nono, because pi-web writes `~/.pi/agent`. The script header and
  `pi-web-tailcat --help` carry the design and the client steps.

## nono

- The profile comes from `home-manager/nono/default.nix` and renders to
  `~/.config/nono/profiles/agents.json`. The option descriptions there carry
  the policy.
- A module adds its runtime home with `dotfiles.nono.filesystem.allow`. Linux
  rejects a deny below a grant, so `~/.cargo` has no credentials deny.
- The exec gate is rebuilt on every activation from the non-writable `PATH`
  directories and their lib closure. Every other store binary fails with
  `EACCES`, which is why a build, `nix fmt` and `nix run` need the user. A tool
  that execs helpers by absolute path needs their directory in
  `commandPolicies.executableDirs`.
- `gh` denies by default against a read-only allowlist, so it needs the
  subcommand path first and no leading flags. `git` allows local work and
  denies the remote operations, and clone is its only networked command. A
  leading global flag skips the git deny list and still leaves git offline.
- `deny_credentials` for `~/.ssh` stays in the outer profile. Only the mediated
  `git commit` sandbox on macOS overrides it for reads.

## build-essential

`gcc.nix` keeps generated ELF files on the stable `~/.local/nix-runtime` prefix
instead of a store hash. See `home-manager/build-essential/README.md`. The
prefix and the GCC `libexec` helpers have their own nono grants, and the prefix
must stay read-only so the exec gate trusts it.

## Git

- `pre-commit` and `pre-push` block `master`, `main`, `release.*` and
  `gh-pages`. Bypass per repository with `git-allow -y` and re-enable with
  `git-allow -n`.
- Home-manager links the hooks into a store linkFarm at `core.hooksPath`. On
  Linux the linkFarm and the Nix Bash directory are in
  `commandPolicies.executableDirs`, and each hook target is in
  `commandPolicies.gitExecPaths`.
- `ghq.root = ~/src`, `GIT_EDITOR = nvim`.

## Neovim

- `home-manager/neovim/default.nix` installs Neovim, lists the plugins and holds
  `init.lua`, a list of `require` calls. Home Manager generates
  `~/.config/nvim/init.lua`, so `home-manager/neovim/nvim/` has none.
- A plugin is one lz.n spec in `nvim/lua/plugins/<plugin>.lua`, where `after`
  sets it up and adds keymaps, and `keys`, `ft` and `event` only trigger. An
  LSP server is a declarative table in `nvim/lsp/<server>.lua`.
- Use `vim.opt.*` (`vim.opt_local.*` in `ftplugin/`), `local` everywhere except
  the statusline, a `desc` on every keymap, and a comment with a `-- ref:` link
  wherever the code needs a reason. A lazy plugin is `optional = true` in
  `programs.neovim.plugins`.

## Tools

Go is a mise tool, and `gopls` is the only Go binary from Nix, because nixpkgs
Go re-execs `$GOROOT/pkg/tool`, which the exec gate denies. Add a tool the same
way: mise when it execs helpers outside `PATH`, Nix otherwise.

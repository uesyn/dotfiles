# Bash sandbox for Pi

Pi runs outside nono. This extension routes the `bash` tool and user `!`/`!!`
through nono by swapping only `shellPath`:

```text
Pi bash tool / ! / !!  →  /nix/store/.../nono-bash
                           nono-bash: exec nono run -s --profile <profile> \
                             --allow-cwd --workdir "$PWD" --no-rollback \
                             --no-audit --no-diagnostics -- <nix bash> "$@"
```

Spawning, streaming, output truncation, timeouts, process-group kills and exit
cleanup stay in Pi's `createLocalBashOperations`. The wrapper is a read-only
store script, so a sandboxed command cannot replace it. Codemode's
`tools.bash()` uses the same override.

## Scope

| Through nono | Directly as Pi |
|---|---|
| `bash`, `!`, `!!` | `write`, `edit`, `read`, `grep`, `find`, `ls`, MCP, other extensions |

`write` and `edit` are not sandboxed; they use Pi's own OS permissions. Treat
Pi's extension and MCP set as trusted.

## Configuration

```nix
dotfiles.pi.sandbox.profile = "agents"; # installed profile name or JSON path
```

`home-manager/pi/default.nix` builds the wrapper and substitutes its store path
into `endpoint.ts`; the extensions tree is copied into one store directory that
`~/.local/share/pi/extensions` links to. Nothing is read at runtime, so project
settings cannot choose the shell or profile. A missing or non-executable
wrapper fails closed.

Restart Pi after `home-manager switch`; `/sandbox on` only re-checks the path
baked into the running extension.

The profile decides filesystem/network/command policy. `agents` grants `~/src`,
`/tmp`, tool homes, the git/gh command policies and networking; a stricter
profile narrows that. Commands cannot add grants by changing directory.

No nested-run support: the wrapper unsets inherited `NONO_*` (an accidental
nested run would otherwise join an outer broker) plus `NODE_OPTIONS`,
`NODE_PATH`, `BASH_ENV` and `ENV`.

## Controls

- `/sandbox`: show status and scope.
- `/sandbox on`: re-check the baked wrapper and re-enable.
- `/sandbox off`: run `bash` and `!`/`!!` directly without nono. No
  confirmation, not persisted; ON returns on startup, reload and session
  switch.
- Switching requires idle Pi with no pending input.
- Failures are ERROR, never OFF: there is no local fallback and no
  model-accessible toggle.
- Plan mode blocks the `bash` tool itself; `!`/`!!` stay available and
  sandboxed while ON. Running processes are not tracked or force-cancelled.

## Cancellation

Abort, timeout and exit use Pi's normal shell handling: SIGKILL to the process
group plus `trackDetachedChildPid` cleanup. Because the wrapper `exec`s nono,
nono and the sandboxed shell share that group. This is not a hard guarantee for
daemons that re-session themselves, and nono's brokered `git`/`gh` children
keep nono's own limits.

## Tests

```sh
PI_TEST_PACKAGE_DIR=/path/to/pi-package \
  node --import ./home-manager/pi/extensions/subagent/tests/register.mjs \
  --test home-manager/pi/extensions/bash-sandbox/tests/*.test.ts

# Opt-in: real installed nono, temporary profiles only.
PI_TEST_PACKAGE_DIR=/path/to/pi-package PI_NONO_INTEGRATION=1 \
  node --import ./home-manager/pi/extensions/subagent/tests/register.mjs \
  --test home-manager/pi/extensions/bash-sandbox/tests/sandbox.test.ts
```

The offline suite covers wrapper routing, disabled-mode local execution,
fail-closed startup (missing or non-executable wrapper, unsubstituted
placeholder), the `/sandbox` toggle, settings parity, plan-mode independence,
`!`/`!!` and codemode. The opt-in suite checks real nono enforcement (cwd
writes, outside and symlink denial, network denial, abort/timeout cleanup,
profile selection) on Linux; macOS enforcement is unverified.

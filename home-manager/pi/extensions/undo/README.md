# pi-undo

Undo/redo for pi agent runs: rewinds the conversation **and** restores the
files that were changed up to that point.

- `/undo [N|all]` — rewind the conversation and restore files to a checkpoint
  - no argument: interactive picker of recent checkpoints
  - `N`: undo the last N agent runs
  - `all`: undo back to the session start
- `/redo [N]` — redo previously undone runs
- `/undo-status` — show the checkpoint stack

## How it works

No git required. The extension implements its own content-addressed snapshot
store:

```
~/.pi/agent/undo/<sessionId>/
├── objects/<sha256>          # file contents (deduplicated)
├── checkpoints/<index>.json  # manifests (path -> hash) per checkpoint
└── (registry.json at the base level for orphan cleanup)
```

- A checkpoint is captured **before the first run** (C0) and **after every
  settled agent run** (Ci) via `before_agent_start` / `agent_settled`.
- Checkpoint *metadata* is persisted in the session as custom entries
  (`pi-undo.checkpoint`), so undo keeps working after a restart or `/resume`.
- The redo stack is persisted the same way (`pi-undo.redo` marker entries,
  rewritten on every undo/redo/clear), so **redo also survives restarts**.
- `/undo` moves the session leaf back to the run boundary with
  `ctx.navigateTree` (no LLM cost) and then applies the reverse file diff from
  the snapshot store. Undone turns remain in the session file and can be
  revisited with `/tree`.
- Manual edits made outside pi between runs are detected (`findDivergentPaths`)
  and trigger a confirmation dialog before being overwritten.

### Snapshot scope

- Root = session working directory (`ctx.cwd`).
- Excludes: `.git`, `.hg`, `.svn`, `.DS_Store`, the extension's own state dir,
  a root-level `.gitignore` (parsed with a built-in matcher), and
  `config.exclude` entries.
- Files larger than `maxFileSizeMB` are skipped.
- Symlinks and permission bits are preserved.

## Configuration

`~/.pi/agent/undo.json` (global) and `.pi/undo.json` (project, project wins):

```jsonc
{
  "autoCheckpoint": true,        // capture a checkpoint after each run
  "maxCheckpoints": 50,          // max checkpoints per session (C0 always kept)
  "confirmBeforeRestore": true,  // confirm before restoring files
  "restorePromptToEditor": true, // put the undone prompt back in the editor
  "exclude": ["node_modules", "dist", "build"],
  "maxFileSizeMB": 20,
  "stateDir": null               // override snapshot store base directory
}
```

## Limitations

- The first run of a brand-new session can be undone to "before the session"
  by rewinding to the first user message (the prompt is restored to the
  editor); the conversation cannot go below the first message (pi tree
  limitation).
- Redo history is cleared (and the clear persisted) on any new user message
  and on manual `/tree` navigation — standard undo/redo semantics. A restart
  does *not* lose it.
- `.gitignore`d files are not snapshotted (use `stateDir`/`exclude` to
  adjust); nested `.gitignore` files are not honored.
- Checkpoints are pruned beyond `maxCheckpoints`; pruning also garbage
  collects unreferenced objects.
- The undone prompt is restored to the editor only when
  `restorePromptToEditor` is enabled and no editor text was already set by the
  navigation.
- Untracked empty directories are not tracked (files only).

## Development

```sh
# unit tests (snapshot engine, gitignore matcher)
bun test test/snapshot.test.ts

# integration tests (spawns real pi --mode rpc; needs a configured provider)
PI_TEST_PROVIDER=deepseek PI_TEST_MODEL=deepseek-v4-flash \
  bun test test/integration.test.ts
```

Type-checking uses the pi package types:

```sh
npm i -D @earendil-works/pi-coding-agent && npx tsc --noEmit
```

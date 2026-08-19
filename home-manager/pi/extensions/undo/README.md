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

Git-backed snapshots, no custom snapshot engine (opencode-style):

```
~/.pi/agent/undo/
├── git/<sha1(worktree)>/     # private gitdir per worktree (project)
│   ├── objects/              # git objects (deduplicated blobs/trees)
│   ├── info/exclude          # rewritten per capture (2MB filter)
│   └── refs/pi-undo/<sessionId>/<index>   # pins checkpoint trees
└── registry.json             # sessionId -> { file, worktree } (orphan GC)
```

- **Requires the session cwd to be inside a git worktree** (like opencode).
  Outside a git worktree `/undo` and `/redo` are unavailable.
- A checkpoint is captured **before the first run** (C0) and **after every
  settled agent run** (Ci) as a git tree hash (`git add -A` + `git write-tree`
  in a private gitdir; the project's own `.git`/index is never touched).
- Checkpoint *metadata* is persisted in the session as custom entries
  (`pi-undo.checkpoint`), so undo keeps working after a restart or `/resume`.
  Trees are pinned with refs, so git gc never collects them.
- The redo stack is persisted the same way (`pi-undo.redo` marker entries,
  rewritten on every undo/redo/clear), so **redo also survives restarts**.
- `/undo` moves the session leaf back to the run boundary with
  `ctx.navigateTree` (no LLM cost) and then applies the file diff between the
  two checkpoint trees with `git checkout <tree> -- <path>` (delete for paths
  that are gone from the target tree). Undone turns remain in the session file
  and can be revisited with `/tree`. `/redo` applies the same diff in the
  other direction.
- Manual edits made outside pi between runs are detected with
  `git diff-files` + `git ls-files --others` (index-based, no full walk) and
  trigger a confirmation dialog before being overwritten.

### Snapshot scope

- Root = the git worktree top-level (`git rev-parse --show-toplevel`), not the
  session cwd, so a session in a subdirectory still snapshots the whole repo.
- Ignore handling is **100% native git**: `.gitignore` files in the worktree
  (root and nested) are honored. The project's `.git/info/exclude` and the
  global `core.excludesFile` are *not* applied to snapshots (they live in the
  project's own gitdir).
- Files larger than **2 MB** are excluded via the private repo's
  `info/exclude` (rewritten every capture, so files that shrink back below the
  limit are picked up again).
- Symlinks and the executable bit are preserved (git mode). Other permission
  bits (e.g. 0600) are normalized on restore, like git itself.
- Submodules (gitlinks) are not snapshotted: a submodule HEAD change shows up
  as one "modified" entry and is skipped during restore.
- Empty directories are not tracked (files only).

## Configuration

`~/.pi/agent/undo.json` (global) and `.pi/undo.json` (project, project wins):

```jsonc
{
  "autoCheckpoint": true,        // capture a checkpoint after each run
  "maxCheckpoints": 50,          // max checkpoints per session (C0 always kept)
  "confirmBeforeRestore": true,  // confirm before restoring files
  "restorePromptToEditor": true  // put the undone prompt back in the editor
}
```

## Limitations

- Requires `git` on PATH and a git worktree. Non-git directories get a
  "undo/redo は git リポジトリ内でのみ利用できます" notification.
- The first run of a brand-new session can be undone to "before the session"
  by rewinding to the first user message (the prompt is restored to the
  editor); the conversation cannot go below the first message (pi tree
  limitation).
- Redo history is cleared (and the clear persisted) on any new user message
  and on manual `/tree` navigation — standard undo/redo semantics. A restart
  does *not* lose it.
- Checkpoints are pruned beyond `maxCheckpoints`; pruning unpins the dropped
  trees (git gc reclaims the objects later).
- The undone prompt is restored to the editor only when
  `restorePromptToEditor` is enabled and no editor text was already set by the
  navigation.
- v1 checkpoints from the previous manifest-store implementation are
  discarded; the old state dirs are removed on session start.

## Development

```sh
# unit tests (git snapshot engine)
bun test test/gitstore.test.ts

# integration tests (spawns real pi --mode rpc; needs a configured provider)
PI_TEST_PROVIDER=deepseek PI_TEST_MODEL=deepseek-v4-flash \
  bun test test/integration.test.ts
```

The integration tests spawn pi with `--no-extensions` so a globally-installed
copy of this extension (e.g. from home-manager into
`~/.local/share/pi/extensions/undo`) does not cause duplicate command
registration (`/undo` would be renamed to `undo:1`).

Type-checking uses the pi package types:

```sh
npm i -D @earendil-works/pi-coding-agent && npx tsc --noEmit
```

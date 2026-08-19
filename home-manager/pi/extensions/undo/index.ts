/**
 * pi-undo — undo/redo for pi agent runs (git-backed, opencode-style).
 *
 * Commands:
 *   /undo [N|all]  — rewind the conversation and restore files to a checkpoint
 *   /redo [N]      — redo previously undone runs
 *   /undo-status   — show the checkpoint stack
 *
 * How it works:
 * - Requires the session cwd to be inside a git worktree (like opencode).
 * - A checkpoint is captured before the first run (C0) and after every
 *   settled agent run (Ci) as a git tree hash in a per-worktree private
 *   gitdir (<agentDir>/undo/git/<hash>). Checkpoint metadata is persisted in
 *   the session via `pi.appendEntry`; trees are pinned with refs so git gc
 *   never collects them.
 * - /undo navigates the session tree back to the run boundary
 *   (`ctx.navigateTree`, summarize disabled) and applies the file difference
 *   between the two checkpoint trees with `git checkout`. Undone turns remain
 *   in the session file and can be revisited with /tree.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadConfig } from "./config.ts";
import { registerCommands } from "./commands.ts";
import {
  captureAfterRun,
  captureInitial,
  persistRedoStack,
  rebuildFromSession,
  setLoadingStatus,
  updateStatus,
} from "./history.ts";
import {
  deleteRefsByPrefix,
  gcAuto,
  gitWorktreeRoot,
  initGitDir,
} from "./gitstore.ts";
import { gcOrphanedSessions, registerSession, removeLegacyStateDir } from "./store.ts";
import { createState, DEFAULT_CONFIG } from "./types.ts";
import type { Config, UndoState } from "./types.ts";

export default function piUndoExtension(pi: ExtensionAPI): void {
  const state: UndoState = createState();
  let config: Config | undefined;
  let gcDone = false;

  const getConfig = (): Config => config ?? DEFAULT_CONFIG;

  /** Serialize git operations (captures, restores) per process. */
  const enqueue = (fn: () => Promise<void>): Promise<void> => {
    const run = state.gitQueue.then(fn);
    state.gitQueue = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  };

  pi.on("session_start", async (_event, ctx) => {
    setLoadingStatus(ctx, "undo準備中...");
    try {
      config = await loadConfig(ctx.cwd);

      const sessionId = ctx.sessionManager.getSessionId();
      const sessionFile = ctx.sessionManager.getSessionFile();
      state.sessionId = sessionId;
      state.ephemeral = !sessionFile;
      state.checkpoints = [];
      state.redoStack = [];
      state.enabled = false;
      state.worktree = "";
      state.gitdir = "";

      // Snapshot/undo requires a git worktree (opencode parity).
      const root = await gitWorktreeRoot(ctx.cwd);
      if (root) {
        state.enabled = true;
        state.worktree = root;
        try {
          state.gitdir = (await initGitDir(root)).gitdir;
        } catch (error) {
          state.enabled = false;
          console.error("pi-undo: gitdir init failed:", error);
        }
      }
      // Discard v1 snapshot data (old manifest store) of this session (D2).
      await removeLegacyStateDir(sessionId);

      await registerSession(sessionId, sessionFile, root);

      // Orphan GC + auto-gc at most once per process.
      if (!gcDone) {
        gcDone = true;
        try {
          await gcOrphanedSessions(sessionId);
        } catch (error) {
          console.error("pi-undo: orphan GC failed:", error);
        }
        if (state.enabled) {
          gcAuto(state.gitdir).catch((error) => console.error("pi-undo: gc failed:", error));
        }
      }

      rebuildFromSession(ctx.sessionManager, state);
    } finally {
      updateStatus(ctx, state);
    }
  });

  // C0: capture the workspace before the first run of the session.
  pi.on("before_agent_start", async (_event, ctx) => {
    const cfg = config;
    if (!cfg?.autoCheckpoint || !state.enabled) return;
    if (state.checkpoints.length > 0) return;
    setLoadingStatus(ctx, "undo初期スナップショットを作成中...");
    try {
      await enqueue(() => captureInitial(ctx, state, pi)).catch((error) => {
        console.error("pi-undo: initial capture failed:", error);
      });
    } finally {
      updateStatus(ctx, state);
    }
  });

  // Ci: capture after every settled agent run (once per run, after retries).
  pi.on("agent_settled", async (_event, ctx) => {
    const cfg = config;
    if (!cfg?.autoCheckpoint || !state.enabled) return;
    setLoadingStatus(ctx, "undoチェックポイントを保存中...");
    try {
      await enqueue(() => captureAfterRun(ctx, state, pi, cfg)).catch((error) => {
        console.error("pi-undo: checkpoint capture failed:", error);
      });
    } finally {
      updateStatus(ctx, state);
    }
  });

  // New user work invalidates the redo stack (standard undo/redo semantics).
  // The clear is persisted so it also holds after a restart.
  pi.on("input", async (event, ctx) => {
    if (event.source === "interactive" || event.source === "rpc") {
      if (state.redoStack.length > 0) {
        state.redoStack = [];
        persistRedoStack(pi, state);
        updateStatus(ctx, state);
      }
    }
    return { action: "continue" };
  });

  // Manual /tree navigation invalidates the redo stack and resyncs state.
  // The marker is always rewritten so a stale marker on the target branch
  // (from a previous undo) cannot resurface after a restart.
  pi.on("session_tree", async (_event, ctx) => {
    if (state.programmaticNavigation) return;
    rebuildFromSession(ctx.sessionManager, state);
    state.redoStack = [];
    persistRedoStack(pi, state);
    updateStatus(ctx, state);
  });

  pi.on("session_shutdown", async () => {
    await state.gitQueue;
    // Ephemeral sessions leave nothing behind: drop their refs.
    if (state.enabled && state.ephemeral && state.gitdir) {
      await deleteRefsByPrefix(state.gitdir, `refs/pi-undo/${state.sessionId}`).catch(() => undefined);
    }
  });

  registerCommands(pi, state, getConfig);
}

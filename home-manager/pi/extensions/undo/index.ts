/**
 * pi-undo — undo/redo for pi agent runs.
 *
 * Commands:
 *   /undo [N|all]  — rewind the conversation and restore files to a checkpoint
 *   /redo [N]      — redo previously undone runs
 *   /undo-status   — show the checkpoint stack
 *
 * How it works:
 * - A checkpoint is captured before the first run (C0) and after every settled
 *   agent run (Ci). Checkpoint metadata is persisted in the session via
 *   `pi.appendEntry`; file contents live in a content-addressed snapshot store
 *   under ~/.pi/agent/undo/<sessionId>/ (no git involved).
 * - /undo navigates the session tree back to the run boundary
 *   (`ctx.navigateTree`, summarize disabled) and then applies the reverse file
 *   diff from the snapshot store.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadConfig } from "./config.ts";
import { registerCommands } from "./commands.ts";
import {
  captureAfterRun,
  captureInitial,
  persistRedoStack,
  rebuildFromSession,
  updateStatus,
} from "./history.ts";
import {
  cleanupEphemeralState,
  ensureStateDir,
  gcOrphanedSessions,
  registerSession,
  resolveStateDir,
  undoBaseDir,
} from "./store.ts";
import { createState, DEFAULT_CONFIG } from "./types.ts";
import type { Config, UndoState } from "./types.ts";

export default function piUndoExtension(pi: ExtensionAPI): void {
  const state: UndoState = createState();
  let config: Config | undefined;
  let gcDone = false;

  const getConfig = (): Config => config ?? DEFAULT_CONFIG;

  pi.on("session_start", async (_event, ctx) => {
    config = await loadConfig(ctx.cwd);

    const sessionId = ctx.sessionManager.getSessionId();
    const sessionFile = ctx.sessionManager.getSessionFile();
    state.stateDir = resolveStateDir(config, sessionId, sessionFile);
    state.ephemeral = !sessionFile;

    await ensureStateDir(state.stateDir);
    await registerSession(undoBaseDir(config), sessionId, sessionFile);

    // GC orphaned sessions at most once per process.
    if (!gcDone) {
      gcDone = true;
      try {
        await gcOrphanedSessions(undoBaseDir(config), sessionId);
      } catch (error) {
        console.error("pi-undo: orphan GC failed:", error);
      }
    }

    rebuildFromSession(ctx.sessionManager, state);
    updateStatus(ctx, state);
  });

  // C0: capture the workspace before the first run of the session.
  pi.on("before_agent_start", async (_event, ctx) => {
    const cfg = config;
    if (!cfg?.autoCheckpoint) return;
    if (state.checkpoints.length > 0) return;
    state.captureQueue = state.captureQueue
      .then(() => captureInitial(ctx, state, pi, cfg, state.stateDir))
      .catch((error) => {
        console.error("pi-undo: initial capture failed:", error);
      });
    await state.captureQueue;
    updateStatus(ctx, state);
  });

  // Ci: capture after every settled agent run (once per run, after retries).
  pi.on("agent_settled", async (_event, ctx) => {
    const cfg = config;
    if (!cfg?.autoCheckpoint) return;
    state.captureQueue = state.captureQueue
      .then(() => captureAfterRun(ctx, state, pi, cfg, state.stateDir))
      .catch((error) => {
        console.error("pi-undo: checkpoint capture failed:", error);
      });
    await state.captureQueue;
    updateStatus(ctx, state);
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
    await state.captureQueue;
    if (state.ephemeral && state.stateDir) {
      await cleanupEphemeralState(state.stateDir);
    }
  });

  registerCommands(pi, state, getConfig);
}

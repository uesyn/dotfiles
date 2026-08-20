/**
 * /undo, /redo and /undo-purge command handlers.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { applyTreeDiff, divergentPaths, filesChangedBetween } from "./gitstore.ts";
import {
  formatCheckpoint,
  persistRedoStack,
  resolveNavigationTarget,
  updateStatus,
} from "./history.ts";
import { purgeSessionStorage } from "./store.ts";
import { PURGE_TYPE } from "./types.ts";
import type { Config, UndoState } from "./types.ts";
import { errorMessage, listPaths, summarizeDiff, truncate } from "./util.ts";

export function registerCommands(
  pi: ExtensionAPI,
  state: UndoState,
  getConfig: () => Config,
): void {
  pi.registerCommand("undo", {
    description:
      "Undo the last agent run(s): rewind the conversation and restore files to that point",
    handler: async (args, ctx) => {
      if (!state.enabled) {
        ctx.ui.notify("pi-undo: undo/redo は git リポジトリ内でのみ利用できます", "warning");
        return;
      }
      await undoCommand(args, ctx, state, getConfig(), pi);
    },
  });

  pi.registerCommand("redo", {
    description: "Redo a previously undone agent run",
    handler: async (args, ctx) => {
      if (!state.enabled) {
        ctx.ui.notify("pi-undo: undo/redo は git リポジトリ内でのみ利用できます", "warning");
        return;
      }
      await redoCommand(args, ctx, state, getConfig(), pi);
    },
  });

  pi.registerCommand("undo-purge", {
    description: "Permanently delete this session's on-disk undo data",
    handler: async (args, ctx) => {
      if (args.trim() !== "") {
        ctx.ui.notify("Usage: /undo-purge — permanently delete this session's undo data", "warning");
        return;
      }
      await purgeSessionCommand(ctx, state, pi);
    },
  });
}

/** Remove all current on-disk undo records for this session. */
async function purgeSessionCommand(
  ctx: ExtensionCommandContext,
  state: UndoState,
  pi: ExtensionAPI,
): Promise<void> {
  await ctx.waitForIdle();
  await state.gitQueue;

  const ok = !ctx.hasUI || await ctx.ui.confirm(
    "Permanently delete undo data?",
    "Delete all on-disk undo data for this session? New checkpoints will be created before the next agent run.",
  );
  if (!ok) return;

  try {
    // This marker prevents session metadata from referring to refs that were
    // removed below when the session is opened again.
    pi.appendEntry(PURGE_TYPE, {});
    await purgeSessionStorage(state.sessionId, state.gitdir);
    state.checkpoints = [];
    state.redoStack = [];
    // Keep the extension enabled: before_agent_start captures a fresh C0 for
    // the next run, making undo/redo available again in this same session.
    updateStatus(ctx, state);
    ctx.ui.notify(
      "pi-undo: purged this session's on-disk undo data; undo is ready for the next agent run.",
      "info",
    );
  } catch (error) {
    ctx.ui.notify(`pi-undo: undo-data purge failed: ${errorMessage(error)}`, "error");
  }
}

async function undoCommand(
  args: string,
  ctx: ExtensionCommandContext,
  state: UndoState,
  config: Config,
  pi: ExtensionAPI,
): Promise<void> {
  await ctx.waitForIdle();
  await state.gitQueue; // drain any in-flight capture

  const { checkpoints } = state;
  if (checkpoints.length <= 1) {
    ctx.ui.notify("⤴ Nothing to undo — no agent runs since the session start checkpoint.");
    return;
  }

  let targetIndex: number;
  const arg = args.trim();
  if (arg === "") {
    const picked = await pickUndoTarget(ctx, state);
    if (picked === undefined) return;
    targetIndex = picked;
  } else if (arg === "all" || arg === "*") {
    targetIndex = 0;
  } else {
    const n = Number.parseInt(arg, 10);
    if (!Number.isInteger(n) || n < 1) {
      ctx.ui.notify("Usage: /undo [N|all] — undo the last N agent runs (default: picker)", "warning");
      return;
    }
    targetIndex = checkpoints.length - 1 - n;
    if (targetIndex < 0) {
      ctx.ui.notify(`Only ${checkpoints.length - 1} run(s) can be undone.`, "warning");
      return;
    }
  }

  await doUndoTo(ctx, state, config, targetIndex, pi);
}

/** Present a picker of undo targets (all checkpoints except the current one). */
async function pickUndoTarget(
  ctx: ExtensionCommandContext,
  state: UndoState,
): Promise<number | undefined> {
  const { checkpoints } = state;
  const options: string[] = [];
  for (let i = checkpoints.length - 2; i >= 1; i--) {
    const meta = checkpoints[i];
    if (meta) options.push(formatCheckpoint(meta));
  }
  options.push("すべて巻き戻し（セッション開始時点へ）");

  const choice = await ctx.ui.select("⤴ Undo to which point?", options);
  if (choice === undefined) return undefined;

  const idx = options.indexOf(choice);
  const sentinel = options.length - 1;
  if (idx === sentinel) return 0;
  return checkpoints.length - 2 - idx;
}

/** Rewind history to `targetIndex` and restore the workspace to match. */
async function doUndoTo(
  ctx: ExtensionCommandContext,
  state: UndoState,
  config: Config,
  targetIndex: number,
  pi: ExtensionAPI,
): Promise<void> {
  const sm = ctx.sessionManager;
  const { checkpoints } = state;
  const target = checkpoints[targetIndex];
  const current = checkpoints[checkpoints.length - 1];
  if (!target || !current) {
    ctx.ui.notify("Checkpoint state unavailable.", "warning");
    return;
  }
  if (targetIndex === checkpoints.length - 1) {
    ctx.ui.notify("Already at that checkpoint.", "info");
    return;
  }

  const store = { gitdir: state.gitdir, worktree: state.worktree };

  const divergent = await divergentPaths(store);
  if (divergent.length > 0 && config.confirmBeforeRestore && ctx.hasUI) {
    const ok = await ctx.ui.confirm(
      "Overwrite manual changes?",
      `Changes made outside pi since the last checkpoint (${divergent.length} file(s)):\n${listPaths(divergent)}\n\nOverwrite them to undo?`,
    );
    if (!ok) return;
  }

  const diff = await filesChangedBetween(store, current.treeHash, target.treeHash);
  if (diff.length > 0 && config.confirmBeforeRestore && ctx.hasUI) {
    const ok = await ctx.ui.confirm(
      "Restore files?",
      `${summarizeDiff(diff)}:\n${listPaths(diff.map((c) => `${c.status} ${c.path}`))}`,
    );
    if (!ok) return;
  }

  // Rewind the conversation first (cancellable, no file side effects).
  const navTarget = resolveNavigationTarget(target, sm);
  state.programmaticNavigation = true;
  let navResult: { cancelled: boolean; editorText?: string };
  try {
    navResult = await ctx.navigateTree(navTarget, { summarize: false });
  } finally {
    state.programmaticNavigation = false;
  }
  if (navResult.cancelled) {
    ctx.ui.notify("Undo cancelled.", "info");
    return;
  }

  // Restore files.
  let restored: string;
  try {
    await applyTreeDiff(store, current.treeHash, target.treeHash);
    restored = summarizeDiff(diff);
  } catch (error) {
    ctx.ui.notify(
      `⤴ File restore failed: ${errorMessage(error)} — run /redo to recover.`,
      "error",
    );
    return;
  }

  // Update stacks and persist the redo stack (survives restarts).
  const undone = checkpoints.slice(targetIndex + 1);
  state.redoStack.push(...[...undone].reverse());
  state.checkpoints = checkpoints.slice(0, targetIndex + 1);
  persistRedoStack(pi, state);

  // Restore the undone prompt into the editor so it can be rephrased.
  if (config.restorePromptToEditor && !navResult.editorText) {
    const prompt = undone[0]?.prompt;
    if (prompt) ctx.ui.setEditorText(prompt);
  }

  updateStatus(ctx, state);
  const label = undone[0]?.prompt ? truncate(undone[0].prompt, 40) : "run";
  ctx.ui.notify(`⤴ Undo: "${label}" — ${restored}`, "info");
}

async function redoCommand(
  args: string,
  ctx: ExtensionCommandContext,
  state: UndoState,
  config: Config,
  pi: ExtensionAPI,
): Promise<void> {
  await ctx.waitForIdle();
  await state.gitQueue; // drain any in-flight capture

  if (state.redoStack.length === 0) {
    ctx.ui.notify("⤵ Nothing to redo.", "info");
    return;
  }

  let count = 1;
  const arg = args.trim();
  if (arg !== "") {
    const n = Number.parseInt(arg, 10);
    if (!Number.isInteger(n) || n < 1) {
      ctx.ui.notify("Usage: /redo [N]", "warning");
      return;
    }
    count = n;
  }

  for (let i = 0; i < count; i++) {
    if (state.redoStack.length === 0) break;
    const ok = await doRedoOne(ctx, state, config, pi);
    if (!ok) break;
  }
}

/** Redo a single undone checkpoint. Returns false when nothing was redone. */
async function doRedoOne(
  ctx: ExtensionCommandContext,
  state: UndoState,
  config: Config,
  pi: ExtensionAPI,
): Promise<boolean> {
  const sm = ctx.sessionManager;
  const entry = state.redoStack[state.redoStack.length - 1];
  const current = state.checkpoints[state.checkpoints.length - 1];
  if (!entry || !current) return false;

  const store = { gitdir: state.gitdir, worktree: state.worktree };

  const divergent = await divergentPaths(store);
  if (divergent.length > 0 && config.confirmBeforeRestore && ctx.hasUI) {
    const ok = await ctx.ui.confirm(
      "Overwrite manual changes?",
      `Changes made outside pi since the last checkpoint (${divergent.length} file(s)):\n${listPaths(divergent)}\n\nOverwrite them to redo?`,
    );
    if (!ok) return false;
  }

  const navTarget = entry.anchorId ?? resolveNavigationTarget(entry, sm);
  state.programmaticNavigation = true;
  let navResult: { cancelled: boolean };
  try {
    navResult = await ctx.navigateTree(navTarget, { summarize: false });
  } finally {
    state.programmaticNavigation = false;
  }
  if (navResult.cancelled) return false;

  const diff = await filesChangedBetween(store, current.treeHash, entry.treeHash);
  try {
    await applyTreeDiff(store, current.treeHash, entry.treeHash);
  } catch (error) {
    ctx.ui.notify(
      `⤵ File restore failed: ${errorMessage(error)} — run /undo to recover.`,
      "error",
    );
    return false;
  }

  state.redoStack.pop();
  state.checkpoints.push(entry);
  persistRedoStack(pi, state);

  updateStatus(ctx, state);
  const label = entry.prompt ? truncate(entry.prompt, 40) : "run";
  ctx.ui.notify(
    `⤵ Redo: "${label}" — ${summarizeDiff(diff)}`,
    "info",
  );
  return true;
}

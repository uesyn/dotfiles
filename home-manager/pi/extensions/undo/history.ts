/**
 * Checkpoint stack management: captures, session rebuilds, navigation target
 * resolution, pruning and status updates.
 */

import type {
  ExtensionAPI,
  ExtensionContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";
import {
  captureSnapshot,
  snapshotOptions,
  summarizeDiff,
} from "./snapshot.ts";
import type { SnapshotOptions } from "./snapshot.ts";
import {
  deleteCheckpointManifest,
  gcObjects,
  loadCheckpointManifest,
  objectsDir,
  saveCheckpointManifest,
} from "./store.ts";
import { CHECKPOINT_VERSION, CUSTOM_TYPE, REDO_TYPE } from "./types.ts";
import type { Checkpoint, CheckpointMeta, Config, UndoState } from "./types.ts";
import { contentText, truncate } from "./util.ts";

/** Build snapshot options for the session (root = session cwd). */
export function buildOptions(
  ctx: ExtensionContext,
  config: Config,
  stateDir: string,
): SnapshotOptions {
  return snapshotOptions(ctx.sessionManager.getCwd(), config, [stateDir]);
}

/** Update the footer status indicator. */
export function updateStatus(ctx: ExtensionContext, state: UndoState): void {
  if (!ctx.hasUI) return;
  const undoCount = Math.max(0, state.checkpoints.length - 1);
  const redoCount = state.redoStack.length;
  ctx.ui.setStatus("pi-undo", `⤴${undoCount} ⤵${redoCount}`);
}

/**
 * Rebuild the checkpoint stack from the session's active branch, and the
 * redo stack from the last `pi-undo.redo` marker on that branch.
 */
export function rebuildFromSession(
  sm: {
    getBranch(): SessionEntry[];
    getEntry(id: string): SessionEntry | undefined;
  },
  state: UndoState,
): void {
  const metas: CheckpointMeta[] = [];
  for (const entry of sm.getBranch()) {
    if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE) continue;
    const data = entry.data as CheckpointMeta | undefined;
    if (
      data &&
      data.v === CHECKPOINT_VERSION &&
      typeof data.index === "number" &&
      data.index >= 0
    ) {
      // The appended data may predate entryId tracking; fix it up so
      // subsequent redo-marker writes can reference this checkpoint.
      metas.push({ ...data, entryId: entry.id });
    }
  }
  metas.sort((a, b) => a.index - b.index);
  state.checkpoints = metas;

  state.redoStack = loadRedoStack(sm);
}

/**
 * Read the redo stack from the last `pi-undo.redo` marker on the active
 * branch. The marker stores session entry ids of the undone checkpoints
 * (newest-first); the checkpoints' metadata is resolved from those entries.
 */
function loadRedoStack(sm: {
  getBranch(): SessionEntry[];
  getEntry(id: string): SessionEntry | undefined;
}): CheckpointMeta[] {
  for (const entry of sm.getBranch()) {
    if (entry.type !== "custom" || entry.customType !== REDO_TYPE) continue;
    const data = entry.data as { redo?: unknown } | undefined;
    if (!data || !Array.isArray(data.redo)) {
      return [];
    }
    const metas: CheckpointMeta[] = [];
    for (const id of data.redo) {
      if (typeof id !== "string") continue;
      const checkpointEntry = sm.getEntry(id);
      if (checkpointEntry?.type !== "custom" || checkpointEntry.customType !== CUSTOM_TYPE) {
        continue;
      }
      const meta = checkpointEntry.data as CheckpointMeta | undefined;
      if (meta && meta.v === CHECKPOINT_VERSION && typeof meta.index === "number") {
        metas.push({ ...meta, entryId: checkpointEntry.id });
      }
    }
    return metas;
  }
  return [];
}

/** Persist the current redo stack as a marker entry at the current leaf. */
export function persistRedoStack(pi: ExtensionAPI, state: UndoState): void {
  const redo = state.redoStack
    .map((meta) => meta.entryId)
    .filter((id): id is string => typeof id === "string");
  pi.appendEntry(REDO_TYPE, { redo });
}

/**
 * Resolve the session entry to navigate to when undoing *past* a checkpoint.
 *
 * C0 of a brand-new session has a null anchor; in that case we navigate to the
 * first user message, which rewinds the conversation below it (navigateTree
 * moves the leaf to its parent and restores the prompt to the editor).
 */
export function resolveNavigationTarget(
  meta: CheckpointMeta,
  sm: { getEntries(): SessionEntry[] },
): string {
  if (meta.anchorId) return meta.anchorId;
  for (const entry of sm.getEntries()) {
    if (entry.type === "message" && entry.message.role === "user") {
      return entry.id;
    }
  }
  throw new Error(`pi-undo: cannot resolve navigation target for checkpoint ${meta.index}`);
}

interface RunInfo {
  promptEntryId?: string;
  prompt?: string;
  promptCount?: number;
}

function findRunInfo(
  sm: {
    getLeafEntry(): SessionEntry | undefined;
    getEntry(id: string): SessionEntry | undefined;
  },
  prevAnchorId: string | null,
): RunInfo {
  let entry = sm.getLeafEntry();
  const userMessages: Array<{ id: string; text: string }> = [];
  while (entry && entry.id !== prevAnchorId) {
    if (entry.type === "message" && entry.message.role === "user") {
      userMessages.push({
        id: entry.id,
        text: contentText(entry.message.content),
      });
    }
    entry = entry.parentId ? sm.getEntry(entry.parentId) : undefined;
  }
  const last = userMessages[userMessages.length - 1];
  return {
    promptEntryId: last?.id,
    prompt: last ? truncate(last.text, 80) : undefined,
    promptCount: userMessages.length > 0 ? userMessages.length : undefined,
  };
}

/** Capture C0: the workspace state before the first run of a session. */
export async function captureInitial(
  ctx: ExtensionContext,
  state: UndoState,
  pi: ExtensionAPI,
  config: Config,
  stateDir: string,
): Promise<void> {
  const sm = ctx.sessionManager;
  const opts = buildOptions(ctx, config, stateDir);
  const { manifest } = await captureSnapshot(opts, null, objectsDir(stateDir));

  const meta: CheckpointMeta = {
    v: CHECKPOINT_VERSION,
    index: 0,
    anchorId: sm.getLeafId(),
    filesChanged: [],
    timestamp: Date.now(),
  };
  await saveCheckpointManifest({ ...meta, manifest }, stateDir);
  state.checkpoints = [meta];
  pi.appendEntry(CUSTOM_TYPE, meta);
  meta.entryId = sm.getLeafId() ?? undefined;
}

/** Capture Ci: the workspace state after a settled agent run. */
export async function captureAfterRun(
  ctx: ExtensionContext,
  state: UndoState,
  pi: ExtensionAPI,
  config: Config,
  stateDir: string,
): Promise<void> {
  const sm = ctx.sessionManager;
  const prev = state.checkpoints[state.checkpoints.length - 1];
  const leafId = sm.getLeafId();
  // Guard against duplicate settle events for the same run.
  if (prev && prev.anchorId === leafId) return;

  const opts = buildOptions(ctx, config, stateDir);
  const prevManifest = prev ? await loadCheckpointManifest(prev, stateDir) : null;
  const { manifest, filesChanged } = await captureSnapshot(
    opts,
    prevManifest,
    objectsDir(stateDir),
  );

  const runInfo = findRunInfo(sm, prev?.anchorId ?? null);

  const meta: CheckpointMeta = {
    v: CHECKPOINT_VERSION,
    index: prev ? prev.index + 1 : 0,
    anchorId: leafId,
    promptEntryId: runInfo.promptEntryId,
    prompt: runInfo.prompt,
    promptCount: runInfo.promptCount,
    filesChanged,
    timestamp: Date.now(),
  };
  await saveCheckpointManifest({ ...meta, manifest }, stateDir);
  state.checkpoints.push(meta);
  pi.appendEntry(CUSTOM_TYPE, meta);
  meta.entryId = sm.getLeafId() ?? undefined;

  const redoChanged = await pruneCheckpoints(state, config, stateDir);
  if (redoChanged) persistRedoStack(pi, state);
}

/**
 * Enforce maxCheckpoints: drop the oldest non-C0 checkpoint and GC objects.
 * Returns true when the redo stack was filtered (caller should persist).
 */
export async function pruneCheckpoints(
  state: UndoState,
  config: Config,
  stateDir: string,
): Promise<boolean> {
  if (state.checkpoints.length <= config.maxCheckpoints) return false;

  const removed = new Set<number>();
  while (state.checkpoints.length > config.maxCheckpoints) {
    const removedMeta = state.checkpoints.splice(1, 1)[0];
    if (removedMeta) {
      removed.add(removedMeta.index);
      await deleteCheckpointManifest(removedMeta.index, stateDir);
    }
  }
  let redoChanged = false;
  if (removed.size > 0) {
    const filtered = state.redoStack.filter((meta) => !removed.has(meta.index));
    redoChanged = filtered.length !== state.redoStack.length;
    state.redoStack = filtered;
  }

  // Garbage-collect objects no longer referenced by retained manifests.
  // Keep manifests referenced by the redo stack too (undo -> restart -> redo
  // must still be able to restore files).
  const keepMetas = [...state.checkpoints, ...state.redoStack];
  const keepManifests: Array<Checkpoint["manifest"]> = [];
  for (const meta of keepMetas) {
    const manifest = await loadCheckpointManifest(meta, stateDir);
    if (manifest) keepManifests.push(manifest);
  }
  await gcObjects(stateDir, keepManifests);
  return redoChanged;
}

/** Format a checkpoint for pickers/status. */
export function formatCheckpoint(meta: CheckpointMeta): string {
  const time = new Date(meta.timestamp).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
  const prompt = meta.prompt ? truncate(meta.prompt, 40) : "(no prompt)";
  return `⤴ ${time} — "${prompt}" (${summarizeDiff(meta.filesChanged)})`;
}

/**
 * Shared types for the pi-undo extension.
 *
 * The extension snapshots the workspace with a private git repository
 * (opencode-style): each checkpoint stores a git tree hash; undo/redo apply
 * the file difference between two checkpoint trees.
 *
 * Checkpoint *metadata* (small) is persisted in the session via
 * `pi.appendEntry(CUSTOM_TYPE, meta)` so it survives restarts; the snapshot
 * itself (git objects) lives in a per-worktree private gitdir under
 * <agentDir>/undo/git/<hash(worktree)>/. Trees are pinned with refs
 * (`refs/pi-undo/<sessionId>/<index>`) so gc never collects them.
 */

/** Version of the persisted checkpoint format (v1 used a manifest store). */
export const CHECKPOINT_VERSION = 2 as const;

/** Custom entry type used to persist checkpoint metadata in the session. */
export const CUSTOM_TYPE = "pi-undo.checkpoint";

/**
 * Custom entry type used to persist the redo stack in the session.
 *
 * Appended at the current leaf whenever the stack changes (undo, redo,
 * clear on new input, manual /tree navigation, pruning). On rebuild the last
 * marker on the active branch wins. Data: { redo: string[] } — session entry
 * ids of the undone checkpoints, newest-first (pop from the end = forward
 * redo order).
 */
export const REDO_TYPE = "pi-undo.redo";

export type FileChangeStatus = "M" | "A" | "D" | "T";

export interface FileChange {
  path: string;
  status: FileChangeStatus;
}

/** Checkpoint metadata. Persisted in the session as a custom entry. */
export interface CheckpointMeta {
  v: typeof CHECKPOINT_VERSION;
  /** Sequential index within the active branch (0 = session start). */
  index: number;
  /**
   * Session entry id of this checkpoint's custom entry. Set in memory after
   * append and fixed up during rebuilds (the appended data itself may not
   * carry it yet).
   */
  entryId?: string;
  /**
   * Session entry id to navigate to when undoing *past* this checkpoint.
   * For C0 (session start) this is the leaf at capture time, or null when
   * the session had no entries yet (resolved to the first user message).
   */
  anchorId: string | null;
  /** Entry id of the last user message that started the captured run. */
  promptEntryId?: string;
  /** Display excerpt of that prompt (max ~80 chars). */
  prompt?: string;
  /** Number of user messages in the run (steer/follow-up aware). */
  promptCount?: number;
  /** Files changed between the previous checkpoint and this one. */
  filesChanged: FileChange[];
  timestamp: number;
  /** Git tree hash of the workspace at this checkpoint. */
  treeHash: string;
}

/** Extension configuration. */
export interface Config {
  /** Capture a checkpoint after each settled agent run. */
  autoCheckpoint: boolean;
  /** Maximum number of checkpoints kept per session (C0 always kept). */
  maxCheckpoints: number;
  /** Ask for confirmation before restoring files (TUI/RPC only). */
  confirmBeforeRestore: boolean;
  /** Restore the undone prompt into the editor after /undo. */
  restorePromptToEditor: boolean;
}

export const DEFAULT_CONFIG: Config = {
  autoCheckpoint: true,
  maxCheckpoints: 50,
  confirmBeforeRestore: true,
  restorePromptToEditor: true,
};

/** In-memory extension state (per session runtime instance). */
export interface UndoState {
  /** Snapshot/undo is available (session cwd is inside a git worktree). */
  enabled: boolean;
  /** Git worktree root (snapshot scope). Empty when disabled. */
  worktree: string;
  /** Private gitdir used for snapshots. Empty when disabled. */
  gitdir: string;
  sessionId: string;
  /** Checkpoints on the active path; index 0 is always the session start. */
  checkpoints: CheckpointMeta[];
  /** Undone checkpoints available for /redo (most recent first). */
  redoStack: CheckpointMeta[];
  /** Serializes git operations (git work must not overlap in-process). */
  gitQueue: Promise<void>;
  /** True while we are navigating the tree ourselves (undo/redo). */
  programmaticNavigation: boolean;
  /** True when the session has no backing file (ephemeral). */
  ephemeral: boolean;
}

export function createState(): UndoState {
  return {
    enabled: false,
    worktree: "",
    gitdir: "",
    sessionId: "",
    checkpoints: [],
    redoStack: [],
    gitQueue: Promise.resolve(),
    programmaticNavigation: false,
    ephemeral: false,
  };
}

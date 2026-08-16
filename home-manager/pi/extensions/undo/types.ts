/**
 * Shared types for the pi-undo extension.
 *
 * The extension implements a content-addressed file snapshot system:
 * - objects/<sha256>: file contents, deduplicated by hash
 * - checkpoints/<index>.json: manifest (path -> hash) per checkpoint
 *
 * Checkpoint *metadata* (small) is persisted in the session via
 * `pi.appendEntry(CUSTOM_TYPE, meta)` so it survives restarts; the manifest
 * itself (potentially large) lives in the state directory.
 */

/** Version of the persisted checkpoint format. */
export const CHECKPOINT_VERSION = 1 as const;

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

/** A regular file entry in a manifest. */
export interface ManifestEntry {
  hash: string;
  size: number;
  mtimeMs: number;
  /** Permission bits, restored on rollback. */
  mode: number;
}

/** A symbolic link entry in a manifest. */
export interface SymlinkEntry {
  symlink: string;
}

export type ManifestValue = ManifestEntry | SymlinkEntry;

/** Manifest: relative path (POSIX, forward slashes) -> content reference. */
export type Manifest = Record<string, ManifestValue>;

export type FileChangeStatus = "M" | "A" | "D";

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
}

/** Checkpoint with its manifest loaded from the state directory. */
export interface Checkpoint extends CheckpointMeta {
  manifest: Manifest;
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
  /** Additional directory patterns to exclude from snapshots. */
  exclude: string[];
  /** Files larger than this (MB) are excluded from snapshots. */
  maxFileSizeMB: number;
  /** Override for the snapshot state directory base. */
  stateDir: string | null;
}

export const DEFAULT_CONFIG: Config = {
  autoCheckpoint: true,
  maxCheckpoints: 50,
  confirmBeforeRestore: true,
  restorePromptToEditor: true,
  exclude: [
    "node_modules",
    "dist",
    "build",
    ".venv",
    "venv",
    "target",
    "__pycache__",
    ".next",
    ".turbo",
    ".cache",
  ],
  maxFileSizeMB: 20,
  stateDir: null,
};

/** In-memory extension state (per session runtime instance). */
export interface UndoState {
  /** Checkpoints on the active path; index 0 is always the session start. */
  checkpoints: CheckpointMeta[];
  /** Undone checkpoints available for /redo (most recent first). */
  redoStack: CheckpointMeta[];
  /** Serializes capture operations (fs work must not overlap). */
  captureQueue: Promise<void>;
  /** True while we are navigating the tree ourselves (undo/redo). */
  programmaticNavigation: boolean;
  /** Resolved snapshot state directory for the current session. */
  stateDir: string;
  /** True when the session has no backing file (ephemeral). */
  ephemeral: boolean;
}

export function createState(): UndoState {
  return {
    checkpoints: [],
    redoStack: [],
    captureQueue: Promise.resolve(),
    programmaticNavigation: false,
    stateDir: "",
    ephemeral: false,
  };
}

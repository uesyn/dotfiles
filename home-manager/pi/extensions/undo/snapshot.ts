/**
 * Content-addressed file snapshot engine (no git required).
 *
 * - `buildManifest` walks the tree and records path -> {hash, size, mtimeMs, mode}
 *   with an mtime/size cache to avoid re-hashing unchanged files.
 * - `captureSnapshot` stores the content of every file that changed since the
 *   previous capture into `objects/<sha256>` (deduplicated).
 * - `applyManifestDiff` makes the working tree match a target manifest by
 *   writing/deleting exactly the paths that differ between two manifests.
 * - `findDivergentPaths` detects manual edits made outside pi before restore.
 */

import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import {
  chmod,
  copyFile,
  lstat,
  mkdir,
  readdir,
  readFile,
  readlink,
  rename,
  rmdir,
  stat,
  symlink,
  rm,
} from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { Gitignore, HARD_EXCLUDES } from "./gitignore.ts";
import type { Config } from "./types.ts";
import type { FileChange, Manifest, ManifestValue } from "./types.ts";

export interface SnapshotOptions {
  root: string;
  maxFileSizeBytes: number;
  gitignore: Gitignore;
  /** Whether the root .gitignore has been merged in yet. */
  gitignoreLoaded: boolean;
  /** Resolved absolute paths that must never be snapshotted (e.g. stateDir). */
  ignoreDirs: Set<string>;
}

/** Build snapshot options for a session. */
export function snapshotOptions(
  root: string,
  config: Config,
  ignoreDirs: string[],
): SnapshotOptions {
  return {
    root,
    maxFileSizeBytes: config.maxFileSizeMB * 1024 * 1024,
    gitignore: new Gitignore([...HARD_EXCLUDES, ...config.exclude]),
    gitignoreLoaded: false,
    ignoreDirs: new Set(ignoreDirs.map((p) => resolve(p))),
  };
}

function sameValue(a: ManifestValue, b: ManifestValue): boolean {
  if ("symlink" in a || "symlink" in b) {
    return "symlink" in a && "symlink" in b && a.symlink === b.symlink;
  }
  // Compare mode as well: a chmod-only change must still be restored.
  return a.hash === b.hash && a.mode === b.mode;
}

async function hashFile(absPath: string): Promise<string> {
  const hash = createHash("sha256");
  const stream = createReadStream(absPath);
  for await (const chunk of stream) {
    hash.update(chunk as Buffer);
  }
  return hash.digest("hex");
}

async function walk(
  dir: string,
  relDir: string,
  opts: SnapshotOptions,
  prev: Manifest | null,
  manifest: Manifest,
): Promise<void> {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
    throw error;
  }

  for (const entry of entries) {
    const relPath = relDir ? `${relDir}/${entry.name}` : entry.name;
    const absPath = join(dir, entry.name);

    if (entry.isDirectory()) {
      if (opts.gitignore.isIgnored(relPath, true)) continue;
      if (opts.ignoreDirs.has(resolve(absPath))) continue;
      await walk(absPath, relPath, opts, prev, manifest);
    } else if (entry.isSymbolicLink()) {
      if (opts.gitignore.isIgnored(relPath, false)) continue;
      if (opts.ignoreDirs.has(resolve(absPath))) continue;
      try {
        const target = await readlink(absPath);
        manifest[relPath] = { symlink: target };
      } catch {
        // Broken link or permission error: skip.
      }
    } else if (entry.isFile()) {
      if (opts.gitignore.isIgnored(relPath, false)) continue;
      if (opts.ignoreDirs.has(resolve(absPath))) continue;
      let st;
      try {
        st = await stat(absPath);
      } catch {
        continue;
      }
      if (st.size > opts.maxFileSizeBytes) continue;

      const prevEntry = prev?.[relPath];
      if (
        prevEntry &&
        !("symlink" in prevEntry) &&
        prevEntry.size === st.size &&
        prevEntry.mtimeMs === st.mtimeMs
      ) {
        // Unchanged since the previous capture: reuse the hash.
        manifest[relPath] = {
          hash: prevEntry.hash,
          size: st.size,
          mtimeMs: st.mtimeMs,
          mode: st.mode,
        };
      } else {
        const hash = await hashFile(absPath);
        manifest[relPath] = {
          hash,
          size: st.size,
          mtimeMs: st.mtimeMs,
          mode: st.mode,
        };
      }
    }
  }
}

/** Build a manifest of the current working tree. */
export async function buildManifest(
  opts: SnapshotOptions,
  prev: Manifest | null,
): Promise<Manifest> {
  if (!opts.gitignoreLoaded) {
    const patterns = await loadRootGitignore(opts.root);
    for (const pattern of patterns) {
      opts.gitignore.addPattern(pattern);
    }
    opts.gitignoreLoaded = true;
  }
  const manifest: Manifest = {};
  await walk(opts.root, "", opts, prev, manifest);
  return manifest;
}

/** Compute the file changes between two manifests. */
export function diffManifests(from: Manifest, to: Manifest): FileChange[] {
  const changes: FileChange[] = [];
  const paths = new Set<string>([...Object.keys(from), ...Object.keys(to)]);
  for (const path of paths) {
    const a = from[path];
    const b = to[path];
    if (!a) {
      changes.push({ path, status: "A" });
    } else if (!b) {
      changes.push({ path, status: "D" });
    } else if (!sameValue(a, b)) {
      changes.push({ path, status: "M" });
    }
  }
  return changes;
}

export interface CaptureResult {
  manifest: Manifest;
  filesChanged: FileChange[];
}

/**
 * Capture the current tree as a checkpoint.
 *
 * Stores the content of every file that is not already in `objectsDir`
 * (so C0 stores everything, later captures only the delta).
 */
export async function captureSnapshot(
  opts: SnapshotOptions,
  prev: Manifest | null,
  objectsDir: string,
): Promise<CaptureResult> {
  const manifest = await buildManifest(opts, prev);
  const filesChanged = prev ? diffManifests(prev, manifest) : [];

  const stored = new Set<string>();
  for (const [relPath, value] of Object.entries(manifest)) {
    if ("symlink" in value) continue;
    const hash = value.hash;
    if (stored.has(hash)) continue;
    stored.add(hash);

    const objPath = join(objectsDir, hash);
    try {
      await lstat(objPath);
      continue; // already stored
    } catch {
      // fall through and store
    }

    const srcPath = join(opts.root, ...relPath.split("/"));
    await mkdir(dirname(objPath), { recursive: true });
    const tmp = `${objPath}.tmp`;
    await copyFile(srcPath, tmp);
    await rename(tmp, objPath);
  }

  return { manifest, filesChanged };
}

/**
 * Make the working tree match `to` for all paths in `from ∪ to`.
 *
 * - writes first (content restored from the object store, atomic via rename)
 * - deletions second (files present in `from` but absent in `to`)
 * - best-effort pruning of empty parent directories afterwards
 */
export async function applyManifestDiff(
  from: Manifest,
  to: Manifest,
  opts: SnapshotOptions,
  objectsDir: string,
): Promise<void> {
  // Write/restore phase.
  for (const [relPath, value] of Object.entries(to)) {
    const fromValue = from[relPath];
    if (fromValue && sameValue(fromValue, value)) continue;

    const absPath = join(opts.root, ...relPath.split("/"));
    await mkdir(dirname(absPath), { recursive: true });

    if ("symlink" in value) {
      await rm(absPath, { force: true });
      await symlink(value.symlink, absPath);
    } else {
      // If a directory sits where the file should be, remove it first.
      let isDir = false;
      try {
        isDir = (await lstat(absPath)).isDirectory();
      } catch {
        // path does not exist
      }
      if (isDir) await rm(absPath, { recursive: true, force: true });

      const objPath = join(objectsDir, value.hash);
      const tmp = `${absPath}.pi-undo.tmp`;
      await copyFile(objPath, tmp);
      await chmod(tmp, value.mode);
      await rename(tmp, absPath);
    }
  }

  // Deletion phase.
  const deletedDirs = new Set<string>();
  for (const relPath of Object.keys(from)) {
    if (to[relPath]) continue;
    const absPath = join(opts.root, ...relPath.split("/"));
    await rm(absPath, { force: true });
    deletedDirs.add(dirname(absPath));
  }

  // Prune empty parent directories (best-effort).
  await pruneEmptyDirs(opts.root, deletedDirs);
}

async function pruneEmptyDirs(
  root: string,
  dirs: Iterable<string>,
): Promise<void> {
  for (const dir of new Set(dirs)) {
    let current = dir;
    while (current.startsWith(root) && current.length > root.length) {
      try {
        await rmdir(current);
      } catch {
        break; // not empty (or gone)
      }
      current = dirname(current);
    }
  }
}

/**
 * Return paths where the current tree differs from an expected manifest.
 * Uses the mtime cache (prev = expected) so unchanged files are skipped.
 */
export async function findDivergentPaths(
  opts: SnapshotOptions,
  expected: Manifest,
): Promise<string[]> {
  const current = await buildManifest(opts, expected);
  const divergent: string[] = [];
  const paths = new Set<string>([...Object.keys(expected), ...Object.keys(current)]);
  for (const path of paths) {
    const a = expected[path];
    const b = current[path];
    if (!a || !b || !sameValue(a, b)) divergent.push(path);
  }
  return divergent;
}

/** Summarize a diff for display. */
export function summarizeDiff(changes: FileChange[]): string {
  const byStatus: Record<string, number> = { M: 0, A: 0, D: 0 };
  for (const c of changes) byStatus[c.status] = (byStatus[c.status] ?? 0) + 1;
  const parts: string[] = [];
  if ((byStatus.M ?? 0) > 0) parts.push(`${byStatus.M ?? 0} modified`);
  if ((byStatus.A ?? 0) > 0) parts.push(`${byStatus.A ?? 0} added`);
  if ((byStatus.D ?? 0) > 0) parts.push(`${byStatus.D ?? 0} deleted`);
  if (parts.length === 0) return "no file changes";
  return parts.join(", ");
}

/** Read the root .gitignore (best-effort; missing file is not an error). */
async function loadRootGitignore(root: string): Promise<string[]> {
  try {
    const content = await readFile(join(root, ".gitignore"), "utf8");
    return content.split(/\r?\n/);
  } catch {
    return [];
  }
}

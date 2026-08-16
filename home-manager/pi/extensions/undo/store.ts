/**
 * State directory management for snapshots.
 *
 * Layout (per session):
 *   <base>/undo/<sessionId>/
 *     objects/<sha256>          - file contents (deduplicated)
 *     checkpoints/<index>.json  - manifests
 *   <base>/undo/registry.json   - sessionId -> sessionFile (orphan GC)
 *
 * `<base>` defaults to the pi agent directory (~/.pi/agent) or
 * `config.stateDir` when set. Ephemeral sessions (no session file) use the
 * system temp directory because there is nothing to restore after a restart.
 */

import { existsSync } from "node:fs";
import { mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import type { Checkpoint, CheckpointMeta, Config } from "./types.ts";
import type { Manifest } from "./types.ts";

/** The pi agent configuration directory (respects PI_CODING_AGENT_DIR). */
export function getAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

/** The base directory that holds per-session undo state. */
export function undoBaseDir(config: Config): string {
  return config.stateDir ?? join(getAgentDir(), "undo");
}

/** Resolve the state directory for a session. */
export function resolveStateDir(
  config: Config,
  sessionId: string,
  sessionFile: string | undefined,
): string {
  if (!sessionFile) {
    // Ephemeral session: nothing to restore across restarts.
    return join(tmpdir(), "pi-undo", sessionId);
  }
  return join(undoBaseDir(config), sessionId);
}

export function objectsDir(stateDir: string): string {
  return join(stateDir, "objects");
}

export function checkpointsDir(stateDir: string): string {
  return join(stateDir, "checkpoints");
}

export async function ensureStateDir(stateDir: string): Promise<void> {
  await mkdir(stateDir, { recursive: true, mode: 0o700 });
  await mkdir(objectsDir(stateDir), { recursive: true, mode: 0o700 });
  await mkdir(checkpointsDir(stateDir), { recursive: true, mode: 0o700 });
}

export async function saveCheckpointManifest(
  checkpoint: Checkpoint,
  stateDir: string,
): Promise<void> {
  const dir = checkpointsDir(stateDir);
  await mkdir(dir, { recursive: true, mode: 0o700 });
  const path = join(dir, `${checkpoint.index}.json`);
  const tmp = `${path}.${process.pid}.tmp`;
  await writeFile(tmp, JSON.stringify(checkpoint.manifest), "utf8");
  await rename(tmp, path);
}

export async function loadCheckpointManifest(
  meta: CheckpointMeta,
  stateDir: string,
): Promise<Manifest | null> {
  try {
    const content = await readFile(
      join(checkpointsDir(stateDir), `${meta.index}.json`),
      "utf8",
    );
    return JSON.parse(content) as Manifest;
  } catch {
    return null;
  }
}

export async function deleteCheckpointManifest(
  index: number,
  stateDir: string,
): Promise<void> {
  await rm(join(checkpointsDir(stateDir), `${index}.json`), { force: true });
}

/** Garbage-collect objects no longer referenced by the given manifests. */
export async function gcObjects(
  stateDir: string,
  keepManifests: Manifest[],
): Promise<void> {
  const keep = new Set<string>();
  for (const manifest of keepManifests) {
    for (const value of Object.values(manifest)) {
      if (!("symlink" in value)) keep.add(value.hash);
    }
  }
  const objects = await readdir(objectsDir(stateDir)).catch(() => []);
  for (const name of objects) {
    if (name.endsWith(".tmp")) continue;
    if (!keep.has(name)) {
      await rm(join(objectsDir(stateDir), name), { force: true });
    }
  }
}

/* ------------------------------ registry ------------------------------ */

interface Registry {
  [sessionId: string]: string | undefined;
}

function registryPath(baseDir: string): string {
  return join(baseDir, "registry.json");
}

async function readRegistry(baseDir: string): Promise<Registry> {
  try {
    const value: unknown = JSON.parse(await readFile(registryPath(baseDir), "utf8"));
    return typeof value === "object" && value !== null
      ? (value as Registry)
      : {};
  } catch {
    return {};
  }
}

async function writeRegistry(baseDir: string, registry: Registry): Promise<void> {
  await mkdir(baseDir, { recursive: true, mode: 0o700 });
  const path = registryPath(baseDir);
  const tmp = `${path}.${process.pid}.tmp`;
  await writeFile(tmp, `${JSON.stringify(registry, null, 2)}\n`, "utf8");
  await rename(tmp, path);
}

/** Record the current session so its state directory survives GC. */
export async function registerSession(
  baseDir: string,
  sessionId: string,
  sessionFile: string | undefined,
): Promise<void> {
  if (!sessionFile) return; // ephemeral: not tracked
  const registry = await readRegistry(baseDir);
  registry[sessionId] = sessionFile;
  await writeRegistry(baseDir, registry);
}

/**
 * Remove state directories whose session file no longer exists.
 * Runs at most once per process (guarded by the caller).
 */
export async function gcOrphanedSessions(
  baseDir: string,
  currentSessionId: string,
): Promise<void> {
  const registry = await readRegistry(baseDir);
  let changed = false;
  for (const [sessionId, file] of Object.entries(registry)) {
    if (sessionId === currentSessionId) continue;
    const dir = join(baseDir, sessionId);
    if (file && !existsSync(file)) {
      await rm(dir, { recursive: true, force: true });
      delete registry[sessionId];
      changed = true;
    } else if (!existsSync(dir)) {
      delete registry[sessionId];
      changed = true;
    }
  }
  if (changed) await writeRegistry(baseDir, registry);
}

/** Remove an ephemeral session's state directory. */
export async function cleanupEphemeralState(stateDir: string): Promise<void> {
  await rm(stateDir, { recursive: true, force: true });
}

/**
 * Session registry and legacy-state cleanup.
 *
 * The registry maps sessionId -> { file, worktree } so orphaned sessions'
 * snapshot refs can be garbage-collected. Private gitdirs are never deleted
 * (git gc reclaims object space); only refs of sessions whose file no longer
 * exists are removed, along with legacy v1 state dirs.
 */

import { existsSync } from "node:fs";
import { mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { deleteRefsByPrefix, gitDirFor, undoBaseDir } from "./gitstore.ts";

interface RegistryEntry {
  file?: string;
  worktree?: string;
}

type Registry = Record<string, string | RegistryEntry>;

function registryPath(): string {
  return join(undoBaseDir(), "registry.json");
}

async function readRegistry(): Promise<Registry> {
  try {
    const value: unknown = JSON.parse(await readFile(registryPath(), "utf8"));
    return typeof value === "object" && value !== null ? (value as Registry) : {};
  } catch {
    return {};
  }
}

async function writeRegistry(registry: Registry): Promise<void> {
  await mkdir(undoBaseDir(), { recursive: true, mode: 0o700 });
  const path = registryPath();
  const tmp = `${path}.${process.pid}.tmp`;
  await writeFile(tmp, `${JSON.stringify(registry, null, 2)}\n`, "utf8");
  await rename(tmp, path);
}

/** Record the current session so its refs survive GC. */
export async function registerSession(
  sessionId: string,
  sessionFile: string | undefined,
  worktree: string | null,
): Promise<void> {
  if (!sessionFile) return; // ephemeral: not tracked
  const registry = await readRegistry();
  registry[sessionId] = { file: sessionFile, worktree: worktree ?? undefined };
  await writeRegistry(registry);
}

/**
 * Remove snapshot refs of sessions whose session file no longer exists, and
 * legacy v1 state dirs. Runs at most once per process (guarded by the caller).
 */
export async function gcOrphanedSessions(currentSessionId: string): Promise<void> {
  const registry = await readRegistry();
  let changed = false;
  for (const [sessionId, entry] of Object.entries(registry)) {
    if (sessionId === currentSessionId) continue;
    const file = typeof entry === "string" ? entry : entry.file;
    const worktree = typeof entry === "object" && entry !== null ? entry.worktree : undefined;
    if (file && existsSync(file)) continue; // still alive
    if (worktree) {
      try {
        await deleteRefsByPrefix(gitDirFor(worktree), `refs/pi-undo/${sessionId}`);
      } catch (error) {
        console.error("pi-undo: ref cleanup failed:", error);
      }
    }
    delete registry[sessionId];
    changed = true;
  }
  if (changed) await writeRegistry(registry);

  // Legacy v1 state dirs (<undoBase>/<sessionId>): drop any that belong to a
  // dead session. The current session's dir is removed in
  // removeLegacyStateDir (session_start).
  const entries = await readdir(undoBaseDir()).catch(() => []);
  for (const name of entries) {
    if (name === "git" || name === "registry.json" || name === currentSessionId) continue;
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(name)) continue;
    const file = typeof registry[name] === "string" ? (registry[name] as string) : undefined;
    if (file && existsSync(file)) continue;
    await rm(join(undoBaseDir(), name), { recursive: true, force: true });
  }
}

/** Remove the legacy v1 state dir of the current session (v1 data is discarded). */
export async function removeLegacyStateDir(sessionId: string): Promise<void> {
  await rm(join(undoBaseDir(), sessionId), { recursive: true, force: true });
}

/**
 * Git-backed snapshot engine (opencode-style, no custom gitignore logic).
 *
 * A per-worktree private git repository stores snapshots:
 *   <agentDir>/undo/git/<sha1(worktree)>/
 *
 * - `capture()` stages the workspace with `git add -A` and returns a tree
 *   hash via `git write-tree`. Ignore handling is 100% native: git honors
 *   `.gitignore` files in the worktree. Files over `MAX_FILE_SIZE` are
 *   excluded via the private repo's `info/exclude` (opencode parity).
 * - `applyTreeDiff(from, to)` makes the workspace match the target tree by
 *   checking out changed paths (`git checkout <tree> -- <path>`) and
 *   deleting paths that are gone from the target tree. Gitlink (submodule)
 *   entries are skipped.
 * - Checkpoint trees are pinned with refs so `git gc` never collects them.
 *
 * The project itself is NOT touched: the private gitdir keeps its own index,
 * objects and config. Works only inside a git worktree (like opencode).
 */

import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, rm, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, relative, resolve } from "node:path";
import type { FileChange } from "./types.ts";

/** Files larger than this are excluded from snapshots (opencode parity). */
const MAX_FILE_SIZE = 2 * 1024 * 1024;

/** The pi agent configuration directory (respects PI_CODING_AGENT_DIR). */
export function getAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

/** Base directory holding all snapshot state. */
export function undoBaseDir(): string {
  return join(getAgentDir(), "undo");
}

/** Private gitdir for a worktree (shared by all sessions in that project). */
export function gitDirFor(worktree: string): string {
  const hash = createHash("sha1").update(resolve(worktree)).digest("hex").slice(0, 16);
  return join(undoBaseDir(), "git", hash);
}

/** Ref that pins a checkpoint tree (kept until the checkpoint is pruned). */
export function refName(sessionId: string, index: number): string {
  return `refs/pi-undo/${sessionId}/${index}`;
}

export interface GitStore {
  gitdir: string;
  worktree: string;
}

interface GitResult {
  code: number;
  stdout: string;
  stderr: string;
}

function runGit(args: string[], opts: { cwd?: string } = {}): Promise<GitResult> {
  return new Promise((resolvePromise, reject) => {
    const child = spawn("git", args, {
      cwd: opts.cwd,
      env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d: Buffer) => (stdout += d.toString("utf8")));
    child.stderr.on("data", (d: Buffer) => (stderr += d.toString("utf8")));
    child.on("error", reject);
    child.on("close", (code) => resolvePromise({ code: code ?? -1, stdout, stderr }));
  });
}

function git(store: GitStore, args: string[]): Promise<GitResult> {
  // Always run from the worktree root so pathspecs are unambiguous.
  return runGit(["--git-dir", store.gitdir, "--work-tree", store.worktree, ...args], {
    cwd: store.worktree,
  });
}

/** Mutating ops retry briefly when another process holds index.lock. */
async function gitLocked(store: GitStore, args: string[]): Promise<GitResult> {
  let result = await git(store, args);
  for (let attempt = 0; attempt < 10 && isLockError(result); attempt++) {
    await new Promise((r) => setTimeout(r, 100));
    result = await git(store, args);
  }
  return result;
}

function isLockError(result: GitResult): boolean {
  return result.code !== 0 && /index\.lock|Unable to create/i.test(result.stderr);
}

/** Resolve the git worktree root for a directory, or null when not in one. */
export async function gitWorktreeRoot(cwd: string): Promise<string | null> {
  const result = await runGit(["-C", cwd, "rev-parse", "--show-toplevel"]);
  if (result.code !== 0) return null;
  const root = result.stdout.trim();
  return root ? root : null;
}

/** Initialize the private gitdir for a worktree (idempotent). */
export async function initGitDir(worktree: string): Promise<GitStore> {
  const store: GitStore = { gitdir: gitDirFor(worktree), worktree };
  const head = join(store.gitdir, "HEAD");
  const initialized = await stat(head)
    .then(() => true)
    .catch(() => false);
  if (!initialized) {
    await mkdir(store.gitdir, { recursive: true, mode: 0o700 });
    const init = await runGit(["--git-dir", store.gitdir, "init", "--quiet"]);
    if (init.code !== 0) throw new Error(`git init failed: ${init.stderr}`);
    for (const [key, value] of [
      ["core.autocrlf", "false"],
      ["core.longpaths", "true"],
      ["core.symlinks", "true"],
      ["core.fsmonitor", "false"],
      ["core.quotepath", "false"],
    ] as const) {
      await runGit(["--git-dir", store.gitdir, "config", key, value]);
    }
  }
  return store;
}

/**
 * Capture the current workspace as a checkpoint tree.
 *
 * Candidates are the tracked changes (`git diff-files`) plus untracked
 * non-ignored files (`git ls-files --others --exclude-standard`); files over
 * MAX_FILE_SIZE are written into the private repo's info/exclude before
 * `git add -A`, so they are never hashed or stored. The exclude file is
 * rewritten on every capture, so files that shrink back below the limit are
 * picked up again (same behavior as opencode).
 */
export async function capture(store: GitStore): Promise<string> {
  const g = (args: string[]) => gitLocked(store, args);

  const [diff, other] = await Promise.all([
    git(store, ["diff-files", "--name-only", "-z", "--", "."]),
    git(store, ["ls-files", "--others", "--exclude-standard", "-z", "--", "."]),
  ]);
  const candidates = Array.from(
    new Set([
      ...diff.stdout.split("\0").filter(Boolean),
      ...other.stdout.split("\0").filter(Boolean),
    ]),
  );

  const large: string[] = [];
  for (let i = 0; i < candidates.length; i += 8) {
    const chunk = candidates.slice(i, i + 8);
    const sizes = await Promise.all(
      chunk.map(async (path) => {
        try {
          return (await stat(join(store.worktree, path))).size;
        } catch {
          return 0; // deleted between listing and stat
        }
      }),
    );
    for (let j = 0; j < sizes.length; j++) {
      const size = sizes[j];
      if (size !== undefined && size > MAX_FILE_SIZE) large.push(chunk[j]!);
    }
  }

  // info/exclude: self-exclusion guard (undo store inside the worktree)
  // + current large files.
  const lines: string[] = [];
  const relBase = relative(resolve(store.worktree), resolve(undoBaseDir()));
  if (relBase && !relBase.startsWith("..")) {
    lines.push(`/${relBase.split("\\").join("/")}/`);
  }
  for (const path of large) lines.push(`/${path.replaceAll("\\", "/")}`);
  await writeFile(
    join(store.gitdir, "info", "exclude"),
    lines.length > 0 ? `${lines.join("\n")}\n` : "",
    "utf8",
  );

  // Drop large files that are already tracked (worktree untouched), then
  // stage everything else. `git add -A` honors info/exclude and .gitignore.
  if (large.length > 0) {
    for (let i = 0; i < large.length; i += 100) {
      await g(["rm", "--cached", "-f", "--ignore-unmatch", "-q", "--", ...large.slice(i, i + 100)]);
    }
  }
  const add = await g(["add", "-A"]);
  if (add.code !== 0) throw new Error(`git add failed: ${add.stderr}`);

  const tree = await g(["write-tree"]);
  if (tree.code !== 0) throw new Error(`git write-tree failed: ${tree.stderr}`);
  return tree.stdout.trim();
}

interface DiffEntry {
  status: "A" | "M" | "D" | "T";
  path: string;
  oldMode: string;
  newMode: string;
}

/** Parse `git diff --raw -z` output (`:oldmode newmode oldsha newsha STATUS\0path\0`). */
function parseRawDiff(text: string): DiffEntry[] {
  const entries: DiffEntry[] = [];
  const parts = text.split("\0");
  let i = 0;
  while (i < parts.length) {
    const header = parts[i++]!;
    if (!header.startsWith(":")) continue;
    const fields = header.slice(1).split(" ");
    if (fields.length < 5) continue;
    const path = parts[i++];
    if (path === undefined) break;
    const status = fields[4];
    if (status !== "A" && status !== "M" && status !== "D" && status !== "T") continue;
    entries.push({ status, path, oldMode: fields[0]!, newMode: fields[1]! });
  }
  return entries;
}

/**
 * Make the workspace match `toTree` for exactly the paths that differ between
 * `fromTree` and `toTree` (undo and redo share this).
 *
 * - A/M/T: `git checkout <toTree> -- <path>` (updates worktree and index)
 * - D:     delete the worktree file, then `git update-index --force-remove`
 * - gitlink (mode 160000, submodules): skipped with a warning
 */
export async function applyTreeDiff(
  store: GitStore,
  fromTree: string,
  toTree: string,
): Promise<void> {
  const g = (args: string[]) => gitLocked(store, args);
  const raw = await g(["diff", "--raw", "-z", "--no-renames", fromTree, toTree]);
  if (raw.code !== 0) throw new Error(`git diff failed: ${raw.stderr}`);

  const checkouts: string[] = [];
  const removals: string[] = [];
  for (const entry of parseRawDiff(raw.stdout)) {
    if (entry.oldMode === "160000" || entry.newMode === "160000") {
      console.warn(`pi-undo: skipping gitlink path (submodule): ${entry.path}`);
      continue;
    }
    if (entry.status === "D") removals.push(entry.path);
    else checkouts.push(entry.path);
  }

  if (removals.length > 0) {
    for (const path of removals) {
      await rm(join(store.worktree, path), { recursive: true, force: true });
    }
    for (let i = 0; i < removals.length; i += 100) {
      const result = await g(["update-index", "--force-remove", "--", ...removals.slice(i, i + 100)]);
      if (result.code !== 0) throw new Error(`git update-index failed: ${result.stderr}`);
    }
  }

  if (checkouts.length > 0) {
    for (let i = 0; i < checkouts.length; i += 100) {
      const result = await g(["checkout", toTree, "--", ...checkouts.slice(i, i + 100)]);
      if (result.code !== 0) throw new Error(`git checkout failed: ${result.stderr}`);
    }
  }
}

/**
 * Paths where the workspace differs from the last checkpoint (manual edits
 * made outside pi). Index-based, no full-tree walk.
 */
export async function divergentPaths(store: GitStore): Promise<string[]> {
  const [diff, other] = await Promise.all([
    git(store, ["diff-files", "--name-only", "-z", "--", "."]),
    git(store, ["ls-files", "--others", "--exclude-standard", "-z", "--", "."]),
  ]);
  return Array.from(
    new Set([
      ...diff.stdout.split("\0").filter(Boolean),
      ...other.stdout.split("\0").filter(Boolean),
    ]),
  );
}

/** Files changed between two checkpoint trees (for display/confirmation). */
export async function filesChangedBetween(
  store: GitStore,
  fromTree: string,
  toTree: string,
): Promise<FileChange[]> {
  const result = await git(store, ["diff", "--name-status", "-z", "--no-renames", fromTree, toTree]);
  const changes: FileChange[] = [];
  const parts = result.stdout.split("\0");
  for (let i = 0; i + 1 < parts.length; i += 2) {
    const status = parts[i]!;
    const path = parts[i + 1]!;
    if (!path) continue;
    changes.push({
      path,
      status: status === "A" || status === "D" || status === "T" ? status : "M",
    });
  }
  return changes;
}

/** Pin a checkpoint tree so gc never collects it. */
export async function setRef(gitdir: string, ref: string, hash: string): Promise<void> {
  const result = await runGit(["--git-dir", gitdir, "update-ref", ref, hash]);
  if (result.code !== 0) throw new Error(`git update-ref failed: ${result.stderr}`);
}

export async function deleteRef(gitdir: string, ref: string): Promise<void> {
  await runGit(["--git-dir", gitdir, "update-ref", "-d", ref]);
}

/** Delete all refs under a prefix (e.g. refs/pi-undo/<sessionId>). */
export async function deleteRefsByPrefix(gitdir: string, prefix: string): Promise<void> {
  const result = await runGit(["--git-dir", gitdir, "for-each-ref", "--format=%(refname)", prefix]);
  if (result.code !== 0) throw new Error(`git for-each-ref failed: ${result.stderr}`);
  for (const ref of result.stdout.split("\n").map((x) => x.trim()).filter(Boolean)) {
    const deleted = await runGit(["--git-dir", gitdir, "update-ref", "-d", ref]);
    if (deleted.code !== 0) throw new Error(`git update-ref failed: ${deleted.stderr}`);
  }
}

/** Fire-and-forget auto GC on the private repo (kept trees stay pinned). */
export async function gcAuto(gitdir: string): Promise<void> {
  const result = await runGit(["--git-dir", gitdir, "gc", "--auto", "--quiet"]);
  if (result.code !== 0) {
    console.error("pi-undo: git gc failed:", result.stderr);
  }
}

/** Reclaim all currently unreachable objects after an explicit session purge. */
export async function gcPrune(gitdir: string): Promise<void> {
  const result = await runGit(["--git-dir", gitdir, "gc", "--prune=now", "--quiet"]);
  if (result.code !== 0) throw new Error(`git gc failed: ${result.stderr}`);
}

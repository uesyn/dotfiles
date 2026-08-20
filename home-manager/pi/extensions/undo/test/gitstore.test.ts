/**
 * Unit tests for the git-backed snapshot engine (run with `bun test`).
 *
 * Points PI_CODING_AGENT_DIR at a temp dir so the private gitdir never
 * touches the real agent directory.
 */

import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { execFile } from "node:child_process";
import { chmod, lstat, mkdir, readFile, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  applyTreeDiff,
  capture,
  deleteRef,
  deleteRefsByPrefix,
  divergentPaths,
  filesChangedBetween,
  gitDirFor,
  gitWorktreeRoot,
  initGitDir,
  undoBaseDir,
  refName,
  setRef,
  type GitStore,
} from "../gitstore.ts";
import { purgeSessionStorage, registerSession } from "../store.ts";

process.env.PI_CODING_AGENT_DIR = join(tmpdir(), `pi-undo-agent-${process.pid}`);

const git = (args: string[], cwd?: string) =>
  new Promise<{ code: number; stdout: string; stderr: string }>((resolve) => {
    execFile("git", args, { cwd }, (error, stdout, stderr) => {
      resolve(error ? { code: (error as { code?: number }).code ?? 1, stdout, stderr } : { code: 0, stdout, stderr });
    });
  });

const treeFiles = async (gitdir: string, tree: string): Promise<string[]> => {
  const result = await git(["--git-dir", gitdir, "ls-tree", "-r", "--name-only", tree]);
  return result.stdout.trim().split("\n").filter(Boolean);
};

let project: string;
let store: GitStore;

beforeAll(async () => {
  project = join(tmpdir(), `pi-undo-gitstore-${process.pid}`);
  await rm(project, { recursive: true, force: true });
  await rm(gitDirFor(project), { recursive: true, force: true });
  await mkdir(project, { recursive: true });
  expect((await git(["init", "-q"], project)).code).toBe(0);
  await git(["config", "user.email", "test@test"], project);
  await git(["config", "user.name", "test"], project);
  store = await initGitDir(project);
});

afterAll(async () => {
  await rm(project, { recursive: true, force: true });
  await rm(gitDirFor(project), { recursive: true, force: true });
  await rm(process.env.PI_CODING_AGENT_DIR!, { recursive: true, force: true });
});

describe("git store", () => {
  it("captures a stable tree hash and never includes the project .git", async () => {
    await writeFile(join(project, "capture.txt"), "alpha");
    const t1 = await capture(store);
    expect(t1).toMatch(/^[0-9a-f]{40}$/);
    const t2 = await capture(store);
    expect(t2).toBe(t1);
    const files = await treeFiles(store.gitdir, t1);
    expect(files).toContain("capture.txt");
    expect(files.some((f) => f.startsWith(".git/"))).toBe(false);
    // index in sync right after capture: no divergent paths
    expect(await divergentPaths(store)).toEqual([]);
  });

  it("tracks modified/added files and restores in both directions", async () => {
    await writeFile(join(project, "round.txt"), "v1");
    const t1 = await capture(store);
    await writeFile(join(project, "round.txt"), "v2");
    await writeFile(join(project, "round-new.txt"), "new");
    const t2 = await capture(store);
    const changes = (await filesChangedBetween(store, t1, t2)).sort((x, y) =>
      x.path.localeCompare(y.path),
    );
    expect(changes).toEqual([
      { path: "round-new.txt", status: "A" },
      { path: "round.txt", status: "M" },
    ]);

    // Undo: T2 -> T1
    await applyTreeDiff(store, t2, t1);
    expect(await readFile(join(project, "round.txt"), "utf8")).toBe("v1");
    await expect(readFile(join(project, "round-new.txt"), "utf8")).rejects.toThrow();
    // Redo: T1 -> T2
    await applyTreeDiff(store, t1, t2);
    expect(await readFile(join(project, "round.txt"), "utf8")).toBe("v2");
    expect(await readFile(join(project, "round-new.txt"), "utf8")).toBe("new");
    // no false divergence after restore
    expect(await divergentPaths(store)).toEqual([]);
  });

  it("restores deleted files", async () => {
    await writeFile(join(project, "deleted.txt"), "delete me");
    const t1 = await capture(store);
    await rm(join(project, "deleted.txt"));
    const t2 = await capture(store);
    expect(await filesChangedBetween(store, t1, t2)).toEqual([
      { path: "deleted.txt", status: "D" },
    ]);
    await applyTreeDiff(store, t2, t1);
    expect(await readFile(join(project, "deleted.txt"), "utf8")).toBe("delete me");
    // and delete again going forward
    await applyTreeDiff(store, t1, t2);
    await expect(readFile(join(project, "deleted.txt"), "utf8")).rejects.toThrow();
    expect(await divergentPaths(store)).toEqual([]);
  });

  it("honors native .gitignore (root and nested)", async () => {
    await writeFile(join(project, ".gitignore"), "*.log\n");
    await mkdir(join(project, "nested-ignore"), { recursive: true });
    await writeFile(join(project, "nested-ignore", ".gitignore"), "*.tmp\n");
    await writeFile(join(project, "debug.log"), "log");
    await writeFile(join(project, "nested-ignore", "x.tmp"), "tmp");
    await writeFile(join(project, "nested-ignore", "keep.txt"), "keep");
    const t = await capture(store);
    const files = await treeFiles(store.gitdir, t);
    expect(files).toContain("nested-ignore/keep.txt");
    expect(files).toContain(".gitignore");
    expect(files).not.toContain("debug.log");
    expect(files).not.toContain("nested-ignore/x.tmp");
  });

  it("excludes files larger than 2MB and re-includes them after shrinking", async () => {
    await writeFile(join(project, "big.bin"), Buffer.alloc(2 * 1024 * 1024 + 1, 0x41));
    const t1 = await capture(store);
    const files = await treeFiles(store.gitdir, t1);
    expect(files).not.toContain("big.bin");

    await writeFile(join(project, "big.bin"), Buffer.alloc(1024, 0x42));
    const t2 = await capture(store);
    expect(await treeFiles(store.gitdir, t2)).toContain("big.bin");
    expect(await filesChangedBetween(store, t1, t2)).toEqual([
      { path: "big.bin", status: "A" },
    ]);
  });

  it("preserves symlinks and the executable bit", async () => {
    await writeFile(join(project, "exec.txt"), "run");
    await chmod(join(project, "exec.txt"), 0o644);
    await symlink("exec.txt", join(project, "exec-link.txt"));
    const t1 = await capture(store);

    await chmod(join(project, "exec.txt"), 0o755);
    await rm(join(project, "exec-link.txt"));
    const t2 = await capture(store);
    expect(await filesChangedBetween(store, t1, t2)).toHaveLength(2);

    await applyTreeDiff(store, t2, t1);
    const mode = (await stat(join(project, "exec.txt"))).mode & 0o777;
    expect(mode).toBe(0o644);
    const link = await lstat(join(project, "exec-link.txt"));
    expect(link.isSymbolicLink()).toBe(true);
  });

  it("detects divergent (manual) changes cheaply", async () => {
    await writeFile(join(project, "div.txt"), "base");
    const t1 = await capture(store);
    await writeFile(join(project, "div.txt"), "manual edit");
    await writeFile(join(project, "div-new.txt"), "new");
    const divergent = (await divergentPaths(store)).sort();
    expect(divergent).toEqual(["div-new.txt", "div.txt"]);
    expect(await treeFiles(store.gitdir, t1)).toContain("div.txt");
  });

  it("handles file <-> directory swaps", async () => {
    await writeFile(join(project, "swap"), "file version");
    const t1 = await capture(store);
    await rm(join(project, "swap"));
    await mkdir(join(project, "swap"));
    await writeFile(join(project, "swap", "inner.txt"), "inner");
    const t2 = await capture(store);
    // git represents the file -> dir change as delete + add.
    const changes = await filesChangedBetween(store, t1, t2);
    expect(changes).toContainEqual({ path: "swap", status: "D" });
    expect(changes).toContainEqual({ path: "swap/inner.txt", status: "A" });
    await applyTreeDiff(store, t2, t1);
    expect(await readFile(join(project, "swap"), "utf8")).toBe("file version");
  });

  it("skips gitlink (submodule) paths in applyTreeDiff", async () => {
    const t1 = await capture(store);
    const submod = join(project, "submod");
    await mkdir(submod, { recursive: true });
    await git(["init", "-q"], submod);
    await writeFile(join(submod, "s.txt"), "sm");
    await git(["add", "-A"], submod);
    await git(["commit", "-qm", "init"], submod);
    const t2 = await capture(store); // git add records the gitlink
    const changes = await filesChangedBetween(store, t1, t2);
    expect(changes).toContainEqual({ path: "submod", status: "A" });
    // must not throw and must not delete the submodule directory
    await expect(applyTreeDiff(store, t2, t1)).resolves.toBeUndefined();
    expect(await readFile(join(submod, "s.txt"), "utf8")).toBe("sm");
  });

  it("manages refs", async () => {
    const t = await capture(store);
    await setRef(store.gitdir, refName("sess-test", 0), t);
    await setRef(store.gitdir, refName("sess-test", 1), t);
    const refs = (await git(["--git-dir", store.gitdir, "for-each-ref", "--format=%(refname)", "refs/pi-undo/sess-test"]))
      .stdout.trim().split("\n").filter(Boolean);
    expect(refs).toHaveLength(2);
    await deleteRef(store.gitdir, refName("sess-test", 0));
    await deleteRefsByPrefix(store.gitdir, "refs/pi-undo/sess-test");
    const after = (await git(["--git-dir", store.gitdir, "for-each-ref", "--format=%(refname)", "refs/pi-undo/sess-test"]))
      .stdout.trim();
    expect(after).toBe("");
  });

  it("purges all on-disk state that belongs to a session", async () => {
    const sessionId = "purge-test";
    const sessionFile = join(project, "purge-session.json");
    const legacyDir = join(undoBaseDir(), sessionId);
    const tree = await capture(store);
    await setRef(store.gitdir, refName(sessionId, 0), tree);
    await writeFile(sessionFile, "{}");
    await mkdir(legacyDir, { recursive: true });
    await writeFile(join(legacyDir, "state.json"), "{}");
    await registerSession(sessionId, sessionFile, project);

    await purgeSessionStorage(sessionId, store.gitdir);

    const refs = await git([
      "--git-dir",
      store.gitdir,
      "for-each-ref",
      "--format=%(refname)",
      `refs/pi-undo/${sessionId}`,
    ]);
    expect(refs.stdout.trim()).toBe("");
    await expect(stat(legacyDir)).rejects.toThrow();
    const registry = JSON.parse(await readFile(join(undoBaseDir(), "registry.json"), "utf8"));
    expect(registry[sessionId]).toBeUndefined();
  });

  it("detects non-git directories and resolves subdirectories of a worktree", async () => {
    const nonGit = join(tmpdir(), `pi-undo-nongit-${process.pid}`);
    await mkdir(nonGit, { recursive: true });
    expect(await gitWorktreeRoot(nonGit)).toBeNull();
    await rm(nonGit, { recursive: true, force: true });
    const subdir = join(project, "deep", "dir");
    await mkdir(subdir, { recursive: true });
    expect(await gitWorktreeRoot(subdir)).toBe(project);
  });
});

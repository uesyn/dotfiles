/**
 * Unit tests for the pi-undo snapshot engine (run with `bun test`).
 */

import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { chmod, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Gitignore } from "../gitignore.ts";
import {
  applyManifestDiff,
  buildManifest,
  captureSnapshot,
  diffManifests,
  findDivergentPaths,
  snapshotOptions,
} from "../snapshot.ts";
import type { Config } from "../types.ts";

const CONFIG: Config = {
  autoCheckpoint: true,
  maxCheckpoints: 50,
  confirmBeforeRestore: true,
  restorePromptToEditor: true,
  exclude: ["node_modules"],
  maxFileSizeMB: 1,
  stateDir: null,
};

let root: string;
let objects: string;

beforeAll(async () => {
  root = join(tmpdir(), `pi-undo-test-${process.pid}`);
  objects = join(root, ".objects");
  await rm(root, { recursive: true, force: true });
  await mkdir(objects, { recursive: true });
});

afterAll(async () => {
  await rm(root, { recursive: true, force: true });
});

const opts = () =>
  snapshotOptions(root, CONFIG, [join(root, ".objects")]);

async function setupFiles(): Promise<void> {
  await mkdir(join(root, "sub"), { recursive: true });
  await mkdir(join(root, "node_modules"), { recursive: true });
  await writeFile(join(root, "a.txt"), "alpha");
  await writeFile(join(root, "sub", "b.txt"), "bravo");
  await writeFile(join(root, "sub", "c.txt"), "charlie");
  await writeFile(join(root, "node_modules", "x.js"), "ignore me");
  await writeFile(join(root, ".gitignore"), "*.log\n.env\n");
  await writeFile(join(root, "secret.env"), "TOP SECRET");
  await writeFile(join(root, "debug.log"), "logs");
  await writeFile(join(root, ".env"), "IGNORED");
}

describe("Gitignore", () => {
  it("matches basic patterns", () => {
    const gi = new Gitignore(["*.log", "build/", "!keep.txt", "node_modules"]);
    expect(gi.isIgnored("debug.log", false)).toBe(true);
    expect(gi.isIgnored("a/b/debug.log", false)).toBe(true);
    expect(gi.isIgnored("build", true)).toBe(true);
    expect(gi.isIgnored("build/x.txt", false)).toBe(true);
    expect(gi.isIgnored("keep.txt", false)).toBe(false);
    expect(gi.isIgnored("node_modules/x.js", false)).toBe(true);
    expect(gi.isIgnored("src/main.ts", false)).toBe(false);
  });

  it("handles anchored and double-star patterns", () => {
    const gi = new Gitignore(["/root.txt", "**/generated/", "a/**/z.txt"]);
    expect(gi.isIgnored("root.txt", false)).toBe(true);
    expect(gi.isIgnored("sub/root.txt", false)).toBe(false);
    expect(gi.isIgnored("x/generated", true)).toBe(true);
    expect(gi.isIgnored("x/y/generated", true)).toBe(true);
    expect(gi.isIgnored("a/b/c/z.txt", false)).toBe(true);
    expect(gi.isIgnored("a/z.txt", false)).toBe(true);
  });
});

describe("snapshot round-trip", () => {
  it("captures C0 with exclusions applied", async () => {
    await setupFiles();
    const { manifest, filesChanged } = await captureSnapshot(opts(), null, objects);

    expect(Object.keys(manifest).sort()).toEqual([
      ".gitignore",
      "a.txt",
      "secret.env",
      "sub/b.txt",
      "sub/c.txt",
    ]);
    expect(manifest["a.txt"]).toBeDefined();
    expect(filesChanged).toEqual([]);
  });

  it("captures a delta and restores in both directions", async () => {
    const c0 = await captureSnapshot(opts(), null, objects);

    // Simulate agent changes between runs.
    await writeFile(join(root, "a.txt"), "alpha v2");
    await rm(join(root, "sub", "b.txt"));
    await writeFile(join(root, "new.txt"), "delta");

    const c1 = await captureSnapshot(opts(), c0.manifest, objects);
    const changes = diffManifests(c0.manifest, c1.manifest).sort((x, y) =>
      x.path.localeCompare(y.path),
    );
    expect(changes).toEqual([
      { path: "a.txt", status: "M" },
      { path: "new.txt", status: "A" },
      { path: "sub/b.txt", status: "D" },
    ]);

    // Undo: C1 -> C0
    await applyManifestDiff(c1.manifest, c0.manifest, opts(), objects);
    expect(await readFile(join(root, "a.txt"), "utf8")).toBe("alpha");
    expect(await readFile(join(root, "sub", "b.txt"), "utf8")).toBe("bravo");
    await expect(readFile(join(root, "new.txt"), "utf8")).rejects.toThrow();
    // Untouched files must remain.
    expect(await readFile(join(root, "sub", "c.txt"), "utf8")).toBe("charlie");
    // Excluded files must never be touched.
    expect(await readFile(join(root, "node_modules", "x.js"), "utf8")).toBe("ignore me");
    expect(await readFile(join(root, "secret.env"), "utf8")).toBe("TOP SECRET");

    // Redo: C0 -> C1
    await applyManifestDiff(c0.manifest, c1.manifest, opts(), objects);
    expect(await readFile(join(root, "a.txt"), "utf8")).toBe("alpha v2");
    expect(await readFile(join(root, "new.txt"), "utf8")).toBe("delta");
    await expect(readFile(join(root, "sub", "b.txt"), "utf8")).rejects.toThrow();
  });

  it("preserves symlinks and permission bits", async () => {
    await symlink("a.txt", join(root, "link.txt"));
    await chmod(join(root, "a.txt"), 0o755);
    const c0 = await captureSnapshot(opts(), null, objects);

    // Break the link and change permissions.
    await rm(join(root, "link.txt"));
    await chmod(join(root, "a.txt"), 0o600);

    const c1 = await captureSnapshot(opts(), c0.manifest, objects);
    await applyManifestDiff(c1.manifest, c0.manifest, opts(), objects);

    const linkStat = await (await import("node:fs/promises")).lstat(join(root, "link.txt"));
    expect(linkStat.isSymbolicLink()).toBe(true);
    const mode = (await (await import("node:fs/promises")).stat(join(root, "a.txt"))).mode;
    expect(mode & 0o777).toBe(0o755);
  });

  it("detects divergent (manual) changes", async () => {
    const c0 = await captureSnapshot(opts(), null, objects);
    await writeFile(join(root, "a.txt"), "manual edit");
    const divergent = await findDivergentPaths(opts(), c0.manifest);
    expect(divergent).toEqual(["a.txt"]);
    await writeFile(join(root, "a.txt"), "alpha");
  });

  it("skips files larger than maxFileSizeMB", async () => {
    const big = Buffer.alloc(2 * 1024 * 1024, 0x41);
    await writeFile(join(root, "big.bin"), big);
    const manifest = await buildManifest(opts(), null);
    expect(manifest["big.bin"]).toBeUndefined();
    await rm(join(root, "big.bin"));
  });
});

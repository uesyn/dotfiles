import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { discoverAndLoadExtensions } from "@earendil-works/pi-coding-agent";

const extensionsDir = fileURLToPath(new URL("../../", import.meta.url));

async function linkTree(source: string, target: string): Promise<void> {
  await mkdir(target, { recursive: true });
  for (const entry of await readdir(source, { withFileTypes: true })) {
    const from = join(source, entry.name);
    const to = join(target, entry.name);
    if (entry.isDirectory()) await linkTree(from, to);
    else await symlink(from, to);
  }
}

test("Home Manager packages sibling extensions in a single source tree", async () => {
  const config = await readFile(join(extensionsDir, "../default.nix"), "utf8");
  assert.match(config, /home\.file\."\.local\/share\/pi\/extensions"\s*=\s*{\s*source\s*=\s*\.\/extensions;/);
  assert.doesNotMatch(config, /home\.file\."\.local\/share\/pi\/extensions\/[^"]+"/);
});

test("Pi loads Home Manager-style file symlinks after realpath resolution", async () => {
  const dir = await mkdtemp(join(tmpdir(), "pi-subagent-deploy-"));
  try {
    const source = join(dir, "store", "hm_extensions");
    const target = join(dir, "home", ".local", "share", "pi", "extensions");
    await cp(extensionsDir, source, { recursive: true });
    await linkTree(source, target);
    assert.equal(
      await realpath(join(target, "subagent", "index.ts")),
      join(source, "subagent", "index.ts"),
    );

    const paths = ["subagent", "plan-mode", "git-readonly"].map((name) => join(target, name));
    const loaded = await discoverAndLoadExtensions(paths, dir, join(dir, "agent"));
    assert.deepEqual(loaded.errors, []);
    assert.equal(loaded.extensions.length, 3);
    assert.ok(loaded.extensions.some((extension) => extension.tools.has("subagent")));
    assert.ok(loaded.extensions.some((extension) => extension.tools.has("git")));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

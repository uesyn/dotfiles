import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { createGitReadonlyTool } from "../index.ts";

test("uses the configured executable instead of git on PATH and fails closed", async () => {
  const dir = mkdtempSync(join(tmpdir(), "pi-git-path-"));
  const previousPath = process.env.PATH;
  writeFileSync(join(dir, "git"), "#!/bin/sh\necho path-git\n", { mode: 0o755 });
  writeFileSync(join(dir, "pinned-git"), "#!/bin/sh\necho pinned-git\n", { mode: 0o755 });
  process.env.PATH = `${dir}:${previousPath ?? ""}`;
  try {
    const params = { operation: "status" as const };
    const ctx = { cwd: process.cwd() } as never;
    const result = await createGitReadonlyTool(join(dir, "pinned-git")).execute("test", params, undefined, undefined, ctx);
    assert.equal(result.isError, false);
    assert.equal(result.details.content, "pinned-git");
    const unconfigured = await createGitReadonlyTool("git").execute("test", params, undefined, undefined, ctx);
    assert.equal(unconfigured.isError, true);
    assert.match(unconfigured.details.content, /not configured/);
    const source = await createGitReadonlyTool().execute("test", params, undefined, undefined, ctx);
    assert.equal(source.isError, true);
    assert.match(source.details.content, /not configured/);
  } finally {
    if (previousPath === undefined) delete process.env.PATH;
    else process.env.PATH = previousPath;
    rmSync(dir, { recursive: true, force: true });
  }
});

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildArgs, createGhReadonlyTool, schema } from "../index.ts";

test("schemas parameters by operation", () => {
  const variants = (schema as unknown as {
    anyOf: Array<{ properties: Record<string, unknown>; required: string[] }>;
  }).anyOf;
  const variant = (operation: string) => variants.find((item) =>
    (item.properties.operation as { const?: string }).const === operation);

  assert.deepEqual(Object.keys(variant("issue_list")!.properties).sort(), ["limit", "operation", "repo", "state"]);
  assert.deepEqual(Object.keys(variant("issue_view")!.properties).sort(), ["number", "operation", "repo"]);
  assert.deepEqual(variant("issue_view")!.required.sort(), ["number", "operation", "repo"]);
  assert.deepEqual(Object.keys(variant("repo_view")!.properties).sort(), ["operation", "repo"]);
});

test("builds fixed read-only commands", () => {
  assert.deepEqual(buildArgs({ operation: "repo_view", repo: "org/repo" }, "github.com"), ["repo", "view", "github.com/org/repo", "--json", "nameWithOwner,description,url,defaultBranchRef,isPrivate"]);
  const args = buildArgs({ operation: "pr_view", repo: "org/repo", number: 42 }, "enterprise.example");
  assert.deepEqual(args.slice(0, 6), ["pr", "view", "42", "--repo", "enterprise.example/org/repo", "--json"]);
  assert.deepEqual(buildArgs({ operation: "issue_list", repo: "org/repo" }, "github.com").slice(0, 8), ["issue", "list", "--repo", "github.com/org/repo", "--limit", "30", "--state", "open"]);
});

test("rejects flag injection, invalid arguments and unsupported operations", () => {
  for (const repo of ["-x/repo", "org/--web", "org/repo --web", "../repo", "host/org/repo"]) {
    assert.throws(() => buildArgs({ operation: "repo_view", repo }, "github.com"));
  }
  assert.throws(() => buildArgs({ operation: "pr_view", repo: "a/b" }, "github.com"));
  assert.throws(() => buildArgs({ operation: "pr_list", repo: "a/b", limit: 101 }, "github.com"));
  assert.throws(() => buildArgs({ operation: "pr_list", repo: "a/b", number: 1 }, "github.com"));
  assert.throws(() => buildArgs({ operation: "repo_view", repo: "a/b" }, "evil/host"));
  assert.throws(() => buildArgs({ operation: "api", repo: "a/b" } as never, "github.com"));
});

test("pre-cancelled calls do not spawn", async () => {
  const controller = new AbortController(); controller.abort();
  const tool = createGhReadonlyTool();
  await assert.rejects(() => tool.execute("test", { operation: "repo_view", repo: "a/b" }, controller.signal, undefined, { cwd: process.cwd() } as never));
});

test("uses the configured executable, not gh on PATH", async () => {
  const dir = mkdtempSync(join(tmpdir(), "gh-path-"));
  const path = process.env.PATH;
  writeFileSync(join(dir, "gh"), "#!/bin/sh\necho path-gh\n", { mode: 0o755 });
  writeFileSync(join(dir, "pinned-gh"), "#!/bin/sh\necho pinned-gh\n", { mode: 0o755 });
  process.env.PATH = `${dir}:${path}`;
  try {
    const params = { operation: "repo_view" as const, repo: "a/b" };
    const ctx = { cwd: process.cwd() } as never;
    const result = await createGhReadonlyTool(join(dir, "pinned-gh")).execute("test", params, undefined, undefined, ctx);
    assert.equal(result.content[0].text.trim(), "pinned-gh");
    await assert.rejects(() => createGhReadonlyTool("gh").execute("test", params, undefined, undefined, ctx), /not configured/);
  } finally {
    if (path === undefined) delete process.env.PATH; else process.env.PATH = path;
    rmSync(dir, { recursive: true, force: true });
  }
});

// Regression: a gh helper that keeps stdout open must not defeat cancellation.
test("abort settles even when a helper holds the pipes open", async () => {
  const dir = mkdtempSync(join(tmpdir(), "gh-fake-"));
  writeFileSync(join(dir, "gh"), "#!/bin/sh\nsleep 60 &\nwait\n", { mode: 0o755 });
  const path = process.env.PATH;
  process.env.PATH = `${dir}:${path}`;
  try {
    const controller = new AbortController();
    setTimeout(() => controller.abort(), 100);
    const started = Date.now();
    const result = await createGhReadonlyTool(join(dir, "gh")).execute("test", { operation: "repo_view", repo: "a/b" }, controller.signal, undefined, { cwd: process.cwd() } as never);
    assert.equal(result.isError, true);
    assert.ok(Date.now() - started < 3000, "cancellation must not wait for the helper");
  } finally {
    if (path === undefined) delete process.env.PATH; else process.env.PATH = path;
    rmSync(dir, { recursive: true, force: true });
  }
});

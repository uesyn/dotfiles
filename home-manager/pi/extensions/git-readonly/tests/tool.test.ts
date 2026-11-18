import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { createGitReadonlyTool, GitParamsSchema } from "../index.ts";

test("schemas parameters by operation", () => {
  const variants = (GitParamsSchema as unknown as {
    anyOf: Array<{ properties: Record<string, unknown>; required: string[] }>;
  }).anyOf;
  const variant = (operation: string) => variants.find((item) =>
    (item.properties.operation as { const?: string }).const === operation);

  assert.equal(variants.length, 7);
  assert.deepEqual(Object.keys(variant("status")!.properties).sort(), [
    "format", "operation", "paths",
  ]);
  assert.deepEqual(Object.keys(variant("log")!.properties).sort(), [
    "author", "max_count", "oneline", "operation", "paths", "rev", "since", "stat", "until",
  ]);
  assert.ok("context" in variant("diff")!.properties);
  assert.ok("context" in variant("show")!.properties);
  assert.ok(!("mode" in variant("show")!.properties));
  assert.ok(!("format" in variant("log")!.properties));
});

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

test("ignores parameters that do not apply to the selected operation", async () => {
  const dir = mkdtempSync(join(tmpdir(), "pi-git-params-"));
  const executable = join(dir, "git");
  writeFileSync(executable, "#!/bin/sh\nexit 0\n", { mode: 0o755 });
  try {
    const tool = createGitReadonlyTool(executable);
    const result = await tool.execute(
      "test",
      {
        operation: "log",
        rev: "main..feat/improve_ci_cache",
        paths: [],
        base: "main",
        head: "feat/improve_ci_cache",
        mode: "range",
        format: "name-only",
        context: 0,
        range_mode: "two-dot",
        author: "",
        since: "",
        until: "",
      },
      undefined,
      undefined,
      { cwd: process.cwd() } as never,
    );

    assert.equal(result.isError, false);
    assert.deepEqual(result.details.argv.slice(-3), [
      "--oneline",
      "--end-of-options",
      "main..feat/improve_ci_cache",
    ]);
    assert.ok(!result.details.argv.some((arg) => arg.startsWith("--author=")));

    const diff = await tool.execute(
      "test",
      {
        operation: "diff",
        mode: "unstaged",
        format: "patch",
        context: 3,
        paths: [],
        rev: "",
        base: "",
        head: "",
        range_mode: "",
        max_count: 20,
        oneline: true,
      },
      undefined,
      undefined,
      { cwd: process.cwd() } as never,
    );
    assert.equal(diff.isError, false);
    assert.ok(!diff.details.argv.includes("--end-of-options"));
    assert.ok(!diff.details.argv.includes("three-dot"));

    const emptyFormat = await tool.execute(
      "test",
      {
        operation: "diff",
        mode: "",
        format: "",
        context: 7,
        paths: [],
        base: "",
        head: "",
        range_mode: "",
      },
      undefined,
      undefined,
      { cwd: process.cwd() } as never,
    );
    assert.equal(emptyFormat.isError, false);
    assert.ok(emptyFormat.details.argv.includes("-U7"));

    const summary = await tool.execute(
      "test",
      {
        operation: "diff",
        mode: "range",
        format: "name-status",
        context: 0,
        base: "origin/feat/billing_delivery",
        head: "HEAD",
      } as never,
      undefined,
      undefined,
      { cwd: process.cwd() } as never,
    );
    assert.equal(summary.isError, false);
    assert.ok(summary.details.argv.includes("--name-status"));
    assert.ok(!summary.details.argv.some((arg) => arg.startsWith("-U")));

    const show = await tool.execute(
      "test",
      { operation: "show", rev: "HEAD", format: "patch", context: 5 },
      undefined,
      undefined,
      { cwd: process.cwd() } as never,
    );
    assert.equal(show.isError, false);
    assert.ok(show.details.argv.includes("-U5"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("still validates parameters that apply to the selected operation", async () => {
  const dir = mkdtempSync(join(tmpdir(), "pi-git-validation-"));
  const executable = join(dir, "git");
  writeFileSync(executable, "#!/bin/sh\nexit 0\n", { mode: 0o755 });
  try {
    const tool = createGitReadonlyTool(executable);
    const ctx = { cwd: process.cwd() } as never;

    await assert.rejects(
      tool.execute(
        "test",
        { operation: "log", rev: "-HEAD" },
        undefined,
        undefined,
        ctx,
      ),
      /"rev" must not start with '-'/,
    );
    await assert.rejects(
      tool.execute(
        "test",
        { operation: "diff", mode: "unstaged", rev: "HEAD" },
        undefined,
        undefined,
        ctx,
      ),
      /not supported for this diff mode/,
    );
    await assert.rejects(
      tool.execute(
        "test",
        { operation: "diff", format: "patch", context: 51 },
        undefined,
        undefined,
        ctx,
      ),
      /"context" must be an integer between 0 and 50/,
    );
    await assert.rejects(
      tool.execute(
        "test",
        { operation: "diff", mode: "range", base: "" },
        undefined,
        undefined,
        ctx,
      ),
      /"base" is required/,
    );
    await assert.rejects(
      tool.execute(
        "test",
        { operation: "rev_parse", what: "toplevel", rev: "HEAD" },
        undefined,
        undefined,
        ctx,
      ),
      /"rev" is not supported when what is "toplevel"/,
    );
    await assert.rejects(
      tool.execute(
        "test",
        { operation: "status", raw: "--porcelain" } as never,
        undefined,
        undefined,
        ctx,
      ),
      /Parameter "raw" is not supported for operation "status"/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

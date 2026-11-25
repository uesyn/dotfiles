import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import { test } from "node:test";
import {
  HEAD_CAPTURE_BYTES,
  STDERR_CAPTURE_BYTES,
  appendStderrToOutput,
  capture,
  writeTempOutput,
} from "../capture.ts";

const node = process.execPath;

function run(script: string, options: { timeoutMs?: number; signal?: AbortSignal } = {}) {
  return capture({
    executable: node,
    argv: ["-e", script],
    cwd: process.cwd(),
    env: process.env,
    timeoutMs: options.timeoutMs ?? 10_000,
    tempPrefix: "pi-capture-test-",
    ...(options.signal !== undefined ? { signal: options.signal } : {}),
  });
}

test("keeps a bounded head and spills the rest to a private file", async () => {
  const result = await run(
    `process.stdout.write("x".repeat(${HEAD_CAPTURE_BYTES + 1000}));`,
  );
  assert.equal(result.stdoutHead.length, HEAD_CAPTURE_BYTES);
  assert.equal(result.stdoutBytes, HEAD_CAPTURE_BYTES + 1000);
  assert.equal(result.exitCode, 0);
  assert.ok(result.fullStdoutPath !== undefined);
  const spilled = readFileSync(result.fullStdoutPath, "utf8");
  assert.equal(spilled.length, HEAD_CAPTURE_BYTES + 1000);
  assert.equal(statSync(result.fullStdoutPath).mode & 0o777, 0o600);
});

test("output below the head cap stays in memory and creates no file", async () => {
  const result = await run(`process.stdout.write("hello");`);
  assert.equal(result.stdoutHead, "hello");
  assert.equal(result.fullStdoutPath, undefined);
});

test("stderr is capped and reports truncation", async () => {
  const result = await run(`process.stderr.write("e".repeat(${STDERR_CAPTURE_BYTES * 2}));`);
  assert.equal(result.stderr.length, STDERR_CAPTURE_BYTES);
  assert.equal(result.stderrTruncated, true);
  assert.equal(result.stderrBytes, STDERR_CAPTURE_BYTES * 2);
});

test("a child that outlives the timeout is killed and reported", async () => {
  const result = await run(`setTimeout(() => {}, 10_000);`, { timeoutMs: 50 });
  assert.equal(result.timedOut, true);
  assert.equal(result.aborted, false);
});

test("an aborted call kills the child and reports cancellation", async () => {
  const controller = new AbortController();
  const pending = run(`setTimeout(() => {}, 10_000);`, { signal: controller.signal });
  controller.abort();
  const result = await pending;
  assert.equal(result.aborted, true);
  assert.equal(result.timedOut, false);
});

test("an already-aborted signal never leaves the child running", async () => {
  const controller = new AbortController();
  controller.abort();
  const result = await run(`setTimeout(() => {}, 10_000);`, { signal: controller.signal });
  assert.equal(result.aborted, true);
});

test("onStdoutLine consumes lines and can stop the child early", async () => {
  const seen: string[] = [];
  const result = await capture({
    executable: node,
    argv: ["-e", `for (let i = 0; i < 10000; i++) console.log("line" + i);`],
    cwd: process.cwd(),
    env: process.env,
    timeoutMs: 10_000,
    tempPrefix: "pi-capture-test-",
    onStdoutLine: (line) => {
      seen.push(line);
      return seen.length < 3 ? undefined : false;
    },
  });
  assert.deepEqual(seen.slice(0, 3), ["line0", "line1", "line2"]);
  assert.ok(seen.length < 10000);
  // Line mode hands every byte to the callback, so nothing is kept in memory.
  assert.equal(result.stdoutHead, "");
});

test("a missing executable rejects instead of resolving", async () => {
  await assert.rejects(
    capture({
      executable: "/nonexistent/pi-capture-test",
      argv: [],
      cwd: process.cwd(),
      env: process.env,
      timeoutMs: 1000,
      tempPrefix: "pi-capture-test-",
    }),
    /ENOENT/,
  );
});

test("writeTempOutput is private and appendStderrToOutput keeps the file whole", () => {
  const path = writeTempOutput("pi-capture-test-", "body");
  assert.equal(statSync(path).mode & 0o777, 0o600);
  assert.equal(readFileSync(path, "utf8"), "body");
  appendStderrToOutput(path, "warn", true);
  assert.equal(readFileSync(path, "utf8"), "body\n\n[stderr]\nwarn\n[stderr truncated]\n");
  // No stderr means no trailing section at all.
  appendStderrToOutput(path, "", false);
  assert.equal(readFileSync(path, "utf8"), "body\n\n[stderr]\nwarn\n[stderr truncated]\n");
});

test("stdoutLimitBytes stops the child instead of spilling", async () => {
  const result = await capture({
    executable: node,
    argv: ["-e", `process.stdout.write("y".repeat(200_000)); setInterval(() => {}, 1000);`],
    cwd: process.cwd(),
    env: process.env,
    timeoutMs: 10_000,
    tempPrefix: "pi-capture-test-",
    stdoutLimitBytes: 4096,
  });
  assert.equal(result.stdoutLimitExceeded, true);
  assert.equal(result.stdoutHead.length, 4096);
  assert.equal(result.fullStdoutPath, undefined);
  assert.equal(result.timedOut, false);
});

test("killProcessGroup settles even when a grandchild holds the pipes", async () => {
  const started = Date.now();
  const result = await capture({
    executable: "/bin/sh",
    argv: ["-c", "sleep 60 & wait"],
    cwd: process.cwd(),
    env: process.env,
    timeoutMs: 100,
    tempPrefix: "pi-capture-test-",
    killProcessGroup: true,
  });
  assert.equal(result.timedOut, true);
  assert.ok(Date.now() - started < 3000, "the timeout must bound the call");
});

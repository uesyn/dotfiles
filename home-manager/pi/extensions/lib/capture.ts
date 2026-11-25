/**
 * Child-process capture shared by the read-only tools.
 *
 * The `ast_grep`, `git` and `gh` tools run a fixed executable, keep a bounded
 * head of stdout in memory, spill the rest to a private temporary file, and
 * report the same timeout/abort/exit information. This module owns that
 * plumbing so each tool keeps only its own argument building and formatting.
 */

import { spawn } from "node:child_process";
import {
  appendFileSync,
  chmodSync,
  closeSync,
  mkdtempSync,
  openSync,
  rmSync,
  writeFileSync,
  writeSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { createInterface } from "node:readline";

export const HEAD_CAPTURE_BYTES = 256 * 1024;
export const STDERR_CAPTURE_BYTES = 64 * 1024;
/** How long a process-group kill may take to produce `close` on its own. */
const FORCE_SETTLE_MS = 1000;

export interface CaptureResult {
  stdoutHead: string;
  stdoutBytes: number;
  stderr: string;
  stderrBytes: number;
  stderrTruncated: boolean;
  /** Set when `stdoutLimitBytes` stopped the child instead of spilling. */
  stdoutLimitExceeded: boolean;
  exitCode: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
  aborted: boolean;
  fullStdoutPath?: string;
}

export interface CaptureOptions {
  executable: string;
  argv: string[];
  cwd: string;
  env: NodeJS.ProcessEnv;
  timeoutMs: number;
  /** Prefix for the private temporary directory that holds spilled output. */
  tempPrefix: string;
  signal?: AbortSignal;
  /**
   * Consume stdout one line at a time instead of capturing it. Returning
   * `false` kills the child, for callers that already have enough output.
   */
  onStdoutLine?: (line: string) => boolean | void;
  /**
   * Stop the child once stdout reaches this many bytes, instead of spilling
   * the excess to a temporary file. Use it when a result that large is a
   * failure, not something to page through.
   */
  stdoutLimitBytes?: number;
  /**
   * Run the child as a process group leader and kill the whole group on
   * timeout, abort or output limit. Needed when the tool spawns helpers that
   * outlive it, since their open pipes would otherwise keep `close` pending.
   */
  killProcessGroup?: boolean;
}

export function capture(options: CaptureOptions): Promise<CaptureResult> {
  const { executable, argv, cwd, env, timeoutMs, tempPrefix, signal } = options;
  const killGroup = options.killProcessGroup === true;
  return new Promise((resolve, reject) => {
    const child = spawn(executable, argv, {
      cwd,
      env,
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
      // A detached child leads its own group, which is what `-pid` addresses.
      detached: killGroup,
    });

    const headChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    let headBytes = 0;
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let stderrCaptured = 0;
    let stderrTruncated = false;
    let stdoutLimitExceeded = false;
    let timedOut = false;
    let aborted = false;
    let settled = false;
    let tempPath: string | undefined;
    let tempFd: number | undefined;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let forceSettle: ReturnType<typeof setTimeout> | undefined;

    const lines =
      options.onStdoutLine === undefined
        ? undefined
        : createInterface({ input: child.stdout, crlfDelay: Infinity });

    function removeTemp(): void {
      if (tempPath === undefined) return;
      try {
        rmSync(dirname(tempPath), { recursive: true, force: true });
      } catch {
        // Best-effort cleanup only.
      }
      tempPath = undefined;
    }

    function cleanup(): void {
      if (timer !== undefined) clearTimeout(timer);
      if (forceSettle !== undefined) clearTimeout(forceSettle);
      if (signal !== undefined) signal.removeEventListener("abort", onAbort);
      if (tempFd !== undefined) {
        try {
          closeSync(tempFd);
        } catch {
          // The stream may already be closed.
        }
        tempFd = undefined;
      }
      lines?.close();
    }

    function ensureTemp(): void {
      if (tempPath !== undefined) return;
      const dir = mkdtempSync(join(tmpdir(), tempPrefix));
      chmodSync(dir, 0o700);
      tempPath = join(dir, "output.txt");
      tempFd = openSync(tempPath, "w", 0o600);
    }

    function stop(): void {
      if (!killGroup) {
        if (!child.killed) child.kill("SIGKILL");
        return;
      }
      if (child.pid !== undefined && child.exitCode === null && child.signalCode === null) {
        try {
          process.kill(-child.pid, "SIGKILL");
        } catch {
          try {
            child.kill("SIGKILL");
          } catch {
            // Already gone.
          }
        }
      }
      // A grandchild that survives the group kill can keep the pipes open, so
      // `close` would never fire and the call would run past its timeout.
      forceSettle ??= setTimeout(() => finish(null, null), FORCE_SETTLE_MS);
    }

    function finish(code: number | null, childSignal: NodeJS.Signals | null): void {
      if (settled) return;
      settled = true;
      cleanup();
      resolve({
        stdoutHead: Buffer.concat(headChunks).toString("utf8"),
        stdoutBytes,
        stderr: Buffer.concat(stderrChunks).toString("utf8"),
        stderrBytes,
        stderrTruncated,
        stdoutLimitExceeded,
        exitCode: code,
        signal: childSignal,
        timedOut,
        aborted,
        fullStdoutPath: tempPath,
      });
    }

    function fail(error: unknown): void {
      if (settled) return;
      settled = true;
      cleanup();
      removeTemp();
      reject(error instanceof Error ? error : new Error(String(error)));
    }

    function onStdout(chunk: Buffer): void {
      stdoutBytes += chunk.length;
      // Line mode hands the payload to the caller instead of keeping it.
      if (lines !== undefined) return;
      try {
        const limit = options.stdoutLimitBytes;
        if (limit !== undefined) {
          const remaining = limit - headBytes;
          const taken = chunk.length <= remaining ? chunk : chunk.subarray(0, Math.max(0, remaining));
          headChunks.push(taken);
          headBytes += taken.length;
          if (taken.length < chunk.length) {
            stdoutLimitExceeded = true;
            stop();
          }
          return;
        }
        if (tempFd !== undefined) {
          writeSync(tempFd, chunk);
          return;
        }
        const remaining = HEAD_CAPTURE_BYTES - headBytes;
        if (chunk.length <= remaining) {
          headChunks.push(chunk);
          headBytes += chunk.length;
          return;
        }
        // Crossing the head limit: move what is buffered into a temporary file
        // first so no output is lost to truncation.
        ensureTemp();
        const fd = tempFd;
        if (fd === undefined) throw new Error("failed to create temporary output file");
        for (const buffered of headChunks) writeSync(fd, buffered);
        writeSync(fd, chunk);
        if (remaining > 0) {
          headChunks.push(chunk.subarray(0, remaining));
          headBytes = remaining;
        }
      } catch (error) {
        stop();
        fail(error);
      }
    }

    function onStderr(chunk: Buffer): void {
      stderrBytes += chunk.length;
      if (stderrCaptured >= STDERR_CAPTURE_BYTES) {
        stderrTruncated = true;
        return;
      }
      const remaining = STDERR_CAPTURE_BYTES - stderrCaptured;
      const taken = chunk.length <= remaining ? chunk : chunk.subarray(0, remaining);
      stderrChunks.push(taken);
      stderrCaptured += taken.length;
      if (taken.length < chunk.length) stderrTruncated = true;
    }

    function onAbort(): void {
      if (settled) return;
      aborted = true;
      stop();
    }

    lines?.on("line", (line) => {
      if (settled) return;
      if (options.onStdoutLine?.(line) === false) stop();
    });

    child.stdout.on("data", onStdout);
    child.stderr.on("data", onStderr);
    child.on("error", fail);
    child.on("close", finish);

    timer = setTimeout(() => {
      timedOut = true;
      stop();
    }, timeoutMs);

    if (signal !== undefined) {
      if (signal.aborted) onAbort();
      else signal.addEventListener("abort", onAbort, { once: true });
    }
  });
}

/**
 * Private file holding output that did not fit the returned content. Callers
 * point the model at it so nothing is lost to truncation.
 */
export function writeTempOutput(tempPrefix: string, text: string): string {
  const dir = mkdtempSync(join(tmpdir(), tempPrefix));
  chmodSync(dir, 0o700);
  const path = join(dir, "output.txt");
  writeFileSync(path, text, { mode: 0o600 });
  return path;
}

/** Attach the capped stderr to a spill file, so the file is the whole story. */
export function appendStderrToOutput(path: string, stderr: string, truncated: boolean): void {
  if (stderr.length === 0) return;
  const suffix = `\n\n[stderr]\n${stderr}${truncated ? "\n[stderr truncated]" : ""}\n`;
  try {
    appendFileSync(path, suffix, { mode: 0o600 });
  } catch {
    // The full-output hint is best-effort; the head is already returned.
  }
}

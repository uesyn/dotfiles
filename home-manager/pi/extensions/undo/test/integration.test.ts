/**
 * Integration test: drives a real pi RPC process with the pi-undo extension
 * loaded and verifies undo/redo behavior end to end.
 *
 * Requires a configured provider with credentials (uses deepseek by default).
 * Run with: bun test test/integration.test.ts
 */

import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { execFileSync, spawn, type ChildProcess } from "node:child_process";
import {
  mkdir,
  mkdtemp,
  readFile,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const EXT_PATH = join(import.meta.dir, "..", "index.ts");
const PI = process.env.PI_BIN ?? "pi";
const PROVIDER = process.env.PI_TEST_PROVIDER ?? "deepseek";
const MODEL = process.env.PI_TEST_MODEL ?? "deepseek-v4-flash";

interface RpcEvent {
  type: string;
  [key: string]: unknown;
}

class RpcClient {
  proc: ChildProcess;
  private buffer = "";
  private idCounter = 0;
  private pending = new Map<
    string,
    { resolve: (v: unknown) => void; reject: (e: Error) => void }
  >();
  private settledQueue: Array<() => void> = [];
  private waitingSettled = 0;
  private exited = false;

  constructor(
    cwd: string,
    sessionDir: string,
    extraArgs: string[] = [],
  ) {
    this.proc = spawn(
      PI,
      [
        "--mode",
        "rpc",
        "--session-dir",
        sessionDir,
        "-e",
        EXT_PATH,
        // Isolate from globally-installed extensions (the undo extension may
        // already be installed via settings; without this the command would
        // be renamed to "undo:1" and /undo would not match).
        "--no-extensions",
        "--provider",
        PROVIDER,
        "--model",
        MODEL,
        ...extraArgs,
      ],
      {
        cwd,
        env: { ...process.env, PI_SKIP_VERSION_CHECK: "1" },
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    this.proc.stdout!.setEncoding("utf8");
    this.proc.stdout!.on("data", (chunk: string) => this.onData(chunk));
    this.proc.stderr!.on("data", (d: Buffer) => {
      process.stderr.write(`[pi-stderr] ${d.toString("utf8")}`);
    });
    this.proc.on("exit", (code) => {
      this.exited = true;
      for (const [, p] of this.pending) {
        p.reject(new Error(`pi exited with code ${code}`));
      }
      this.pending.clear();
      const waiters = [...this.settledQueue];
      this.settledQueue = [];
      for (const w of waiters) w();
    });
  }

  private onData(chunk: string): void {
    this.buffer += chunk;
    let idx: number;
    while ((idx = this.buffer.indexOf("\n")) >= 0) {
      const line = this.buffer.slice(0, idx).trim();
      this.buffer = this.buffer.slice(idx + 1);
      if (!line) continue;
      let msg: RpcEvent;
      try {
        msg = JSON.parse(line) as RpcEvent;
      } catch {
        continue;
      }
      this.handleMessage(msg);
    }
  }

  private handleMessage(msg: RpcEvent): void {
    if (msg.type === "response") {
      const id = msg.id as string;
      const pending = this.pending.get(id);
      if (pending) {
        this.pending.delete(id);
        if (msg.success) pending.resolve(msg.data);
        else pending.reject(new Error(`command failed: ${JSON.stringify(msg)}`));
      }
      return;
    }
    if (msg.type === "extension_ui_request") {
      const method = msg.method as string;
      if (method === "confirm" || method === "select" || method === "input") {
        // Auto-cancel unexpected dialogs.
        this.proc.stdin!.write(
          `${JSON.stringify({ type: "extension_ui_response", id: msg.id, cancelled: true })}\n`,
        );
      }
      return;
    }
    if (msg.type === "agent_settled") {
      if (this.waitingSettled > 0) {
        this.waitingSettled--;
        this.settledQueue.shift()?.();
      }
    }
  }

  send(command: string, body: Record<string, unknown> = {}): Promise<unknown> {
    const id = `req-${++this.idCounter}`;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.proc.stdin!.write(`${JSON.stringify({ id, type: command, ...body })}\n`);
    });
  }

  waitForSettled(timeoutMs = 240_000): Promise<void> {
    if (this.exited) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const i = this.settledQueue.indexOf(handler);
        if (i >= 0) this.settledQueue.splice(i, 1);
        reject(new Error("timeout waiting for agent_settled"));
      }, timeoutMs);
      this.waitingSettled++;
      const handler = () => {
        clearTimeout(timer);
        resolve();
      };
      this.settledQueue.push(handler);
    });
  }

  /** Send a prompt and wait for the run to fully settle. */
  async prompt(message: string): Promise<void> {
    await this.send("prompt", { message });
    await this.waitForSettled();
  }

  /** Invoke an extension command (e.g. /undo) and wait for the response. */
  async command(command: string): Promise<void> {
    await this.send("prompt", { message: command });
  }

  async close(): Promise<void> {
    if (this.exited) return;
    this.proc.kill("SIGTERM");
    await new Promise<void>((resolve) => {
      if (this.exited) return resolve();
      this.proc.once("exit", () => resolve());
    });
  }
}

function textOf(message: unknown): string {
  const m = message as { content?: unknown };
  if (typeof m.content === "string") return m.content;
  if (Array.isArray(m.content)) {
    return m.content
      .filter((b) => (b as { type?: string }).type === "text")
      .map((b) => (b as { text?: string }).text ?? "")
      .join("\n");
  }
  return "";
}

const TIMEOUT = 240_000;

let dir: string;
let sessionDir: string;
let projectDir: string;
let nonGitDir: string;
let client: RpcClient;

beforeAll(
  async () => {
    dir = await mkdtemp(join(tmpdir(), "pi-undo-it-"));
    sessionDir = join(dir, "sessions");
    projectDir = join(dir, "project");
    nonGitDir = join(dir, "non-git");
    await mkdir(join(projectDir, ".pi"), { recursive: true });
    await mkdir(sessionDir, { recursive: true });
    await mkdir(nonGitDir, { recursive: true });
    // The snapshot engine requires a git worktree (opencode parity).
    execFileSync("git", ["init", "-q"], { cwd: projectDir });
    execFileSync("git", ["config", "user.email", "test@test"], { cwd: projectDir });
    execFileSync("git", ["config", "user.name", "test"], { cwd: projectDir });
    await writeFile(
      join(projectDir, ".pi", "undo.json"),
      JSON.stringify({ confirmBeforeRestore: false, restorePromptToEditor: false }),
    );
  },
  TIMEOUT,
);

afterAll(async () => {
  await rm(dir, { recursive: true, force: true });
});

describe("pi-undo integration", () => {
  it(
    "undo restores files and rewinds history; redo restores forward",
    async () => {
      client = new RpcClient(projectDir, sessionDir, ["--name", "undo-it-1"]);
      try {
        await client.prompt("Create a file named a.txt whose content is exactly: hello");

        expect(await readFile(join(projectDir, "a.txt"), "utf8")).toBe("hello");

        await client.prompt(
          "Change the content of a.txt to exactly: world. Also create a file named b.txt whose content is exactly: bee",
        );
        expect(await readFile(join(projectDir, "a.txt"), "utf8")).toBe("world");
        expect(await readFile(join(projectDir, "b.txt"), "utf8")).toBe("bee");

        // --- undo run 2 ---
        await client.command("/undo 1");
        expect(await readFile(join(projectDir, "a.txt"), "utf8")).toBe("hello");
        await expect(readFile(join(projectDir, "b.txt"), "utf8")).rejects.toThrow();

        // History must be rewound: the second prompt is no longer in the context.
        const msgs = (await client.send("get_messages")) as { messages: unknown[] };
        const userTexts = msgs.messages
          .filter((m) => (m as { role?: string }).role === "user")
          .map(textOf);
        expect(userTexts.at(-1) ?? "").toContain("a.txt");
        expect(userTexts.at(-1) ?? "").not.toContain("b.txt");

        // --- redo run 2 ---
        await client.command("/redo");
        expect(await readFile(join(projectDir, "a.txt"), "utf8")).toBe("world");
        expect(await readFile(join(projectDir, "b.txt"), "utf8")).toBe("bee");

        // --- undo all the way back to session start ---
        await client.command("/undo all");
        await expect(readFile(join(projectDir, "a.txt"), "utf8")).rejects.toThrow();
        await expect(readFile(join(projectDir, "b.txt"), "utf8")).rejects.toThrow();
      } finally {
        await client.close();
      }
    },
    TIMEOUT,
  );

  it(
    "undo works after restarting pi (checkpoints persisted)",
    async () => {
      const client1 = new RpcClient(projectDir, sessionDir, ["--name", "undo-it-2"]);      let sessionFile: string;
      try {
        await client1.prompt("Create a file named c.txt whose content is exactly: charlie");
        expect(await readFile(join(projectDir, "c.txt"), "utf8")).toBe("charlie");
        const state = (await client1.send("get_state")) as { sessionFile?: string };
        sessionFile = state.sessionFile as string;
        expect(sessionFile).toBeTruthy();
      } finally {
        await client1.close();
      }

      // Restart pi against the same session file.
      client = new RpcClient(projectDir, sessionDir, [
        "--name",
        "undo-it-2b",
        "--session",
        sessionFile,
      ]);
      try {
        await client.command("/undo 1");
        await expect(readFile(join(projectDir, "c.txt"), "utf8")).rejects.toThrow();
      } finally {
        await client.close();
      }
    },
    TIMEOUT,
  );

  it(
    "redo survives a restart after undo (redo stack persisted)",
    async () => {
      const client1 = new RpcClient(projectDir, sessionDir, ["--name", "undo-it-3"]);
      let sessionFile: string;
      try {
        await client1.prompt("Create a file named d.txt whose content is exactly: delta");
        await client1.prompt("Change the content of d.txt to exactly: omega");
        expect(await readFile(join(projectDir, "d.txt"), "utf8")).toBe("omega");

        // Undo run 2, then restart before redoing.
        await client1.command("/undo 1");
        expect(await readFile(join(projectDir, "d.txt"), "utf8")).toBe("delta");
        const state = (await client1.send("get_state")) as { sessionFile?: string };
        sessionFile = state.sessionFile as string;
      } finally {
        await client1.close();
      }

      client = new RpcClient(projectDir, sessionDir, [
        "--name",
        "undo-it-3b",
        "--session",
        sessionFile,
      ]);
      try {
        // After restart, the redo stack must be rebuilt from the marker.
        await client.command("/redo");
        expect(await readFile(join(projectDir, "d.txt"), "utf8")).toBe("omega");
      } finally {
        await client.close();
      }
    },
    TIMEOUT,
  );

  it(
    "undo is unavailable outside a git worktree",
    async () => {
      const client2 = new RpcClient(nonGitDir, sessionDir, ["--name", "undo-it-4"]);
      try {
        await client2.prompt("Create a file named e.txt whose content is exactly: echo");
        expect(await readFile(join(nonGitDir, "e.txt"), "utf8")).toBe("echo");
        // Snapshot engine is disabled: /undo must leave the file alone.
        await client2.command("/undo 1");
        expect(await readFile(join(nonGitDir, "e.txt"), "utf8")).toBe("echo");
      } finally {
        await client2.close();
      }
    },
    TIMEOUT,
  );
});

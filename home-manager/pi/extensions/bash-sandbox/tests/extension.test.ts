import assert from "node:assert/strict";
import { test } from "node:test";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  createBashToolDefinition, createEventBus,
  type ExtensionAPI, type ExtensionCommandContext, type ExtensionToolContext,
} from "@earendil-works/pi-coding-agent";
import { installBashSandbox } from "../index.ts";
import { createState, type State } from "../state.ts";

async function wrapper(dir: string, body = "printf 'sandboxed\\n'; exit 3"): Promise<string> {
  const file = join(dir, "nono-bash");
  await writeFile(file, `#!/bin/sh\n${body}\n`);
  await chmod(file, 0o755);
  return file;
}

async function mock(bakedShell?: string, settings: { shellPath?: string; shellCommandPrefix?: string } = {}) {
  const dir = await mkdtemp(join(tmpdir(), "pi-bash-sandbox-"));
  const shell = await wrapper(dir);
  const tools = new Map<string, any>();
  const commands = new Map<string, any>();
  const handlers = new Map<string, any[]>();
  const notifications: string[] = [];
  const notifyKinds: string[] = [];
  const statuses: string[] = [];
  const branch: any[] = [];
  let idle = true;
  const state: State = createState();
  const api = {
    events: createEventBus(),
    getSettings: () => settings,
    registerTool: (tool: any) => tools.set(tool.name, tool),
    registerCommand: (name: string, value: any) => commands.set(name, value.handler),
    on: (name: string, handler: any) => { handlers.set(name, [...(handlers.get(name) ?? []), handler]); return () => {}; },
  } as unknown as ExtensionAPI;
  const ctx = {
    cwd: dir, hasUI: true, isIdle: () => idle, hasPendingMessages: () => false,
    sessionManager: { getBranch: () => branch, getSessionId: () => "s", getSessionFile: () => undefined },
    ui: {
      notify: (message: string, type?: string) => { notifications.push(message); notifyKinds.push(type ?? "info"); },
      setStatus: (_key: string, text: string | undefined) => statuses.push(text ?? ""),
      theme: { fg: (_color: string, text: string) => text },
    },
  } as unknown as ExtensionToolContext & ExtensionCommandContext;
  installBashSandbox(api, state, bakedShell ?? shell);
  return {
    api, ctx, state, tools, notifications, notifyKinds, statuses, branch, shell, dir,
    idle: (value: boolean) => { idle = value; },
    command: (args: string) => commands.get("sandbox")(args, ctx),
    emit: async (name: string) => { let value; for (const handler of handlers.get(name) ?? []) value = await handler({}, ctx); return value; },
  };
}

test("only bash is overridden and it keeps the built-in schema and prompt metadata", async () => {
  const m = await mock();
  assert.deepEqual([...m.tools.keys()], ["bash"]);
  const base = createBashToolDefinition("/tmp");
  for (const key of ["parameters", "promptSnippet", "promptGuidelines", "outputSchema"]) assert.deepEqual(m.tools.get("bash")[key], (base as any)[key]);
  assert.equal(m.state.shell, null);
});

test("ON uses the Home Manager wrapper as the shell and keeps Pi's output semantics", async () => {
  const m = await mock();
  await m.emit("session_start");
  assert.equal(m.state.shell, m.shell);
  assert.equal(m.statuses.at(-1), "Sandbox ON");
  const result = await m.tools.get("bash").execute("b", { command: "ignored" }, undefined, undefined, m.ctx);
  assert.equal(result.structuredContent.exit_code, 3);
  assert.match(result.content[0].text, /sandboxed/);
  assert.equal(result.isError, true);
});

test("settings remain effective: command prefix in ON, shellPath when OFF", async () => {
  const dir = await mkdtemp(join(tmpdir(), "pi-settings-test-"));
  try {
    const recorder = join(dir, "nono-bash");
    await writeFile(recorder, `#!/bin/sh\nprintf '%s' "$2" > '${join(dir, "command.txt")}'\n`);
    await chmod(recorder, 0o755);
    const custom = join(dir, "custom-shell");
    await writeFile(custom, "#!/bin/sh\nprintf 'custom shell\\n'\n");
    await chmod(custom, 0o755);
    const m = await mock(recorder, {
      shellPath: custom, shellCommandPrefix: "PREFIX",
    });
    await m.emit("session_start");
    await m.tools.get("bash").execute("b", { command: "real" }, undefined, undefined, m.ctx);
    assert.equal(await readFile(join(dir, "command.txt"), "utf8"), "PREFIX\nreal");
    await m.command("off");
    const result = await m.tools.get("bash").execute("b", { command: "ignored" }, undefined, undefined, m.ctx);
    assert.equal(result.structuredContent.exit_code, 0);
    assert.match(result.content[0].text, /custom shell/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test("startup failure is fail-closed for both the tool and user bash", async () => {
  const m = await mock(join(tmpdir(), "pi-missing-nono-bash"));
  await m.emit("session_start");
  assert.equal(m.state.enabled, true);
  assert.equal(m.state.shell, null);
  assert.match(m.state.error, /missing or not executable/);
  assert.equal(m.statuses.at(-1), "Sandbox ERROR");
  await assert.rejects(m.tools.get("bash").execute("b", { command: "true" }, undefined, undefined, m.ctx), /missing or not executable/);
  await assert.rejects(m.emit("user_bash"), /missing or not executable/);
});

test("OFF requires idle, runs locally, and restart resets ON", async () => {
  const m = await mock();
  await m.emit("session_start");
  m.idle(false);
  await m.command("off");
  assert.equal(m.state.enabled, true);
  m.idle(true);
  await m.command("off");
  assert.equal(m.state.enabled, false);
  const result = await m.tools.get("bash").execute("b", { command: "printf local > local.txt" }, undefined, undefined, m.ctx);
  assert.equal(result.structuredContent.exit_code, 0);
  assert.equal(await readFile(join(m.dir, "local.txt"), "utf8"), "local");
  await m.emit("session_start");
  assert.equal(m.state.enabled, true);
});

test("OFF needs no confirmation and works without UI", async () => {
  const m = await mock();
  await m.emit("session_start");
  m.ctx.hasUI = false;
  await m.command("off");
  assert.equal(m.state.enabled, false);
  assert.equal(await m.emit("user_bash"), undefined);
});

// Plan mode disables model tools (including bash) on its own; user-initiated
// !/!! remain available and stay sandboxed while the sandbox is ON.
test("user bash is not gated by plan mode", async () => {
  const m = await mock();
  await m.emit("session_start");
  m.branch.push({ type: "custom", customType: "plan-mode", data: { enabled: true } });
  const userBash = await m.emit("user_bash");
  assert.deepEqual(await userBash.operations.exec("ignored", m.dir, { onData() {} }), { exitCode: 3 });
});

test("user bash uses the wrapper while enabled and yields to Pi when disabled", async () => {
  const m = await mock();
  await m.emit("session_start");
  const enabled = await m.emit("user_bash");
  assert.deepEqual(await enabled.operations.exec("ignored", m.dir, { onData() {} }), { exitCode: 3 });
  await m.command("off");
  assert.equal(await m.emit("user_bash"), undefined);
});

test("status output reflects the switch that just happened", async () => {
  const m = await mock();
  await m.emit("session_start");
  await m.command("off");
  assert.match(m.notifications.at(-1)!, /Sandbox OFF/);
  await m.command("on");
  assert.match(m.notifications.at(-1)!, /Sandbox ON/);
});

test("a broken sandbox is reported as an error, not as info", async () => {
  const m = await mock(join(tmpdir(), "pi-missing-nono-bash"));
  await m.emit("session_start");
  await m.command("");
  assert.match(m.notifications.at(-1)!, /Sandbox ERROR/);
  assert.equal(m.notifyKinds.at(-1), "error");
});

test("shutdown clears the status indicator", async () => {
  const m = await mock();
  await m.emit("session_start");
  await m.emit("session_shutdown");
  assert.equal(m.statuses.at(-1), "");
});

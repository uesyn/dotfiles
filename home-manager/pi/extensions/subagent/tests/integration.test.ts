import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { access, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  createAssistantMessageEventStream,
  type AssistantMessageEventStream,
  getCurrentSystemPrompt,
  getCurrentTools,
  type AssistantMessage,
  type CredentialStore,
  type Provider,
} from "@earendil-works/pi-ai";
import {
  createEventBus,
  ModelRegistry,
  ModelRuntime,
  type AgentSession,
  type ExtensionAPI,
  type ExtensionContext,
  type ExtensionToolContext,
  type SessionEntry,
  type ToolDefinition,
} from "@earendil-works/pi-coding-agent";
import planMode from "../../plan-mode/index.ts";
import { createGitReadonlyTool } from "../../git-readonly/index.ts";
import subagent, { boundOutput, SubagentSchema, validateTasks, type SubagentDetails } from "../index.ts";
import { createChildSession, emptyUsage, runTask, type ChildSession, type ParentContext, type TaskResult } from "../runner.ts";

let dir: string;
const previousHome = process.env.HOME;
const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
before(async () => {
  dir = await mkdtemp(join(tmpdir(), "pi-subagent-test-"));
  process.env.HOME = dir;
  process.env.PI_CODING_AGENT_DIR = join(dir, ".pi", "agent");
});
after(async () => {
  if (previousHome === undefined) delete process.env.HOME;
  else process.env.HOME = previousHome;
  if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
  await rm(dir, { recursive: true, force: true });
});

const model = {
  id: "mock-model", name: "Mock", api: "openai-completions", provider: "subagent-test",
  baseUrl: "https://must-not-be-contacted.invalid", reasoning: true,
  input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  contextWindow: 100_000, maxTokens: 2000,
} as const;
const credentials: CredentialStore = {
  read: async () => undefined, list: async () => [],
  modify: async () => { throw new Error("Unexpected credential write"); },
  delete: async () => { throw new Error("Unexpected credential delete"); },
};

function answer(text = "done", stopReason: AssistantMessage["stopReason"] = "stop"): AssistantMessage {
  const usage = emptyUsage();
  usage.input = 10;
  usage.output = 2;
  usage.totalTokens = 12;
  return {
    role: "assistant", content: [{ type: "text", text }], api: model.api,
    provider: model.provider, model: model.id, usage, stopReason, timestamp: Date.now(),
  };
}

function deliver(stream: AssistantMessageEventStream, message: AssistantMessage): void {
  stream.push({ type: "start", partial: message });
  if (message.stopReason === "error" || message.stopReason === "aborted") {
    stream.push({ type: "error", reason: message.stopReason, error: message });
  } else {
    stream.push({ type: "done", reason: message.stopReason as "stop" | "toolUse", message });
  }
  stream.end();
}

async function parent(streamSimple: Provider["streamSimple"]): Promise<ParentContext> {
  const runtime = await ModelRuntime.create({ modelsPath: null, credentials, refreshOnCreate: false });
  runtime.registerNativeProvider({
    id: model.provider, name: "Registered at runtime",
    getModels: () => [{ ...model, input: ["text"] }],
    auth: { apiKey: { name: "Mock auth", resolve: async () => ({ auth: { apiKey: "parent-only-key" } }) } },
    stream: () => { throw new Error("Expected provider-neutral streaming"); },
    streamSimple,
  });
  await runtime.refresh({ allowNetwork: false, providers: [model.provider] });
  return {
    cwd: dir,
    model: runtime.getModel(model.provider, model.id),
    thinkingLevel: "high",
    modelRegistry: new ModelRegistry(runtime),
  };
}

function mockPi(parentContext: ParentContext) {
  type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
  type Command = (args: string, ctx: ExtensionContext) => Promise<void>;
  let tool!: ToolDefinition<typeof SubagentSchema, SubagentDetails>;
  const handlers = new Map<string, Handler[]>();
  const commands = new Map<string, Command>();
  const branch: SessionEntry[] = [];
  let active = ["read", "bash", "edit", "write", "codemode", "git", "subagent"];
  const events = createEventBus();
  const api = {
    events,
    registerTool: (value: typeof tool) => { tool = value; },
    registerCommand: (name: string, value: { handler: Command }) => { commands.set(name, value.handler); },
    on: (name: string, handler: Handler) => {
      handlers.set(name, [...(handlers.get(name) ?? []), handler]);
      return () => {};
    },
    getThinkingLevel: () => "high",
    getActiveTools: () => [...active],
    setActiveTools: (tools: string[]) => { active = [...tools]; },
    appendEntry: (customType: string, data: unknown) => {
      branch.push({ type: "custom", customType, data, id: String(branch.length), parentId: null, timestamp: new Date().toISOString() });
    },
  } as unknown as ExtensionAPI;
  const ctx = {
    ...parentContext,
    hasUI: false,
    sessionManager: { getBranch: () => branch },
  } as unknown as ExtensionToolContext;
  planMode(api);
  subagent(api);
  return {
    api, ctx, commands,
    active: () => active,
    tool: () => tool,
    emit: async (name: string, value = {}) => {
      for (const handler of handlers.get(name) ?? []) await handler(value, ctx);
    },
  };
}

async function waitUntil(check: () => boolean): Promise<void> {
  const deadline = Date.now() + 5000;
  while (!check()) {
    if (Date.now() > deadline) throw new Error("Timed out waiting for mock provider");
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
}

test("actual SDK session has only read-only tools, isolated context, and parent auth", async () => {
  const cwd = join(dir, "resource-test");
  await mkdir(join(cwd, ".pi", "extensions"), { recursive: true });
  await writeFile(join(cwd, "AGENTS.md"), "Project instruction marker");
  await writeFile(join(cwd, "evidence.txt"), "file evidence");
  await writeFile(join(cwd, ".pi", "extensions", "evil.ts"), 'throw new Error("Project extension must never load");');
  await writeFile(join(cwd, ".pi", "settings.json"), "not valid JSON");
  const toolNames: string[][] = [];
  let requests = 0;
  const context = await parent((_model, transcript, options) => {
    assert.equal(options?.apiKey, "parent-only-key");
    assert.equal(options?.reasoning, "high");
    toolNames.push(getCurrentTools(transcript.messages).map((tool) => tool.name));
    assert.match(getCurrentSystemPrompt(transcript.messages), /Project instruction marker/);
    assert.match(getCurrentSystemPrompt(transcript.messages), /read-only scout/);
    const stream = createAssistantMessageEventStream();
    const message = answer();
    if (++requests === 1) {
      message.stopReason = "toolUse";
      message.content = [
        { type: "toolCall", id: "read", name: "read", arguments: { path: "evidence.txt" } },
        ...["write", "bash", "subagent", "codemode", "mcp__evil__tool"].map((name) => ({
          type: "toolCall" as const, id: name, name,
          arguments: { path: "must-not-exist", content: "bad", command: "touch must-not-exist" },
        })),
      ];
    } else {
      const results = transcript.messages.filter((message) => message.role === "toolResult");
      assert.equal(results.length, 6);
      assert.equal(results[0].isError, false);
      assert.match(JSON.stringify(results[0].content), /file evidence/);
      for (const result of results.slice(1)) assert.equal(result.isError, true);
    }
    queueMicrotask(() => deliver(stream, message));
    return stream;
  });
  context.cwd = cwd;
  const session = await createChildSession(context, "scout", new AbortController().signal) as AgentSession;
  try {
    assert.deepEqual(session.getActiveToolNames().sort(), ["find", "git", "grep", "ls", "read"]);
    assert.equal(session.thinkingLevel, "high");
    assert.equal(session.sessionFile, undefined);
    await session.prompt("Inspect evidence.txt");
    assert.equal(session.getLastAssistantText(), "done");
    assert.equal(requests, 2);
    assert.deepEqual(toolNames[0].sort(), ["find", "git", "grep", "ls", "read"]);
    await assert.rejects(access(join(cwd, "must-not-exist")));
  } finally {
    session.dispose();
  }
});

test("cancellation during SDK prompt preflight never dispatches a model request", async () => {
  let requests = 0;
  const context = await parent(() => {
    requests++;
    const stream = createAssistantMessageEventStream();
    queueMicrotask(() => deliver(stream, answer("must not run after cancellation")));
    return stream;
  });
  const controller = new AbortController();
  const result: TaskResult = {
    id: "preflight", agent: "scout", status: "queued", output: "", turns: 0, usage: emptyUsage(),
  };
  await runTask(result, "cancel while starting", context, controller.signal, () => {}, {
    timeoutMs: 1000,
    createSession: async (...args) => {
      const session = await createChildSession(...args);
      const wrapped: ChildSession = {
        prompt: session.prompt.bind(session),
        abort: session.abort.bind(session),
        dispose: session.dispose.bind(session),
        subscribe: (listener) => {
          const unsubscribe = session.subscribe(listener);
          // prompt() awaits preflight before starting its agent run. abort()
          // alone is ineffective in that window, so the provider must gate it.
          queueMicrotask(() => controller.abort("cancel during preflight"));
          return unsubscribe;
        },
      };
      return wrapped;
    },
  });
  assert.equal(result.status, "cancelled");
  assert.equal(requests, 0);
});

test("tool preserves successful siblings, input order, and nested usage on partial failure", async () => {
  const context = await parent((_model, transcript) => {
    const stream = createAssistantMessageEventStream();
    const failed = JSON.stringify(transcript.messages).includes("fail this task");
    const message = answer(failed ? "partial evidence" : "successful evidence", failed ? "error" : "stop");
    if (failed) message.errorMessage = "mock provider failure";
    queueMicrotask(() => deliver(stream, message));
    return stream;
  });
  const pi = mockPi(context);
  const output = await pi.tool().execute("call", { tasks: [
    { agent: "reviewer", task: "fail this task" },
    { agent: "planner", task: "succeed" },
  ] }, undefined, undefined, pi.ctx);
  assert.equal(output.isError, true);
  assert.deepEqual(output.details.results.map((result) => result.status), ["failed", "completed"]);
  assert.deepEqual(output.details.results.map((result) => result.agent), ["reviewer", "planner"]);
  assert.equal(output.usage?.input, 20);
  assert.equal(new Set(output.details.results.map((result) => result.id)).size, 2);
  assert.equal(pi.tool().exposure, "model-only");
  await pi.emit("session_shutdown");
});

test("two-slot limit spans tool calls; plan mode cancels active and queued tasks", async () => {
  let running = 0;
  let peak = 0;
  let started = 0;
  const context = await parent((_model, _transcript, options) => {
    const stream = createAssistantMessageEventStream();
    started++;
    peak = Math.max(peak, ++running);
    const stop = () => {
      running--;
      deliver(stream, answer("", "aborted"));
    };
    if (options?.signal?.aborted) queueMicrotask(stop);
    else options?.signal?.addEventListener("abort", stop, { once: true });
    return stream;
  });
  const pi = mockPi(context);
  const first = pi.tool().execute("one", { tasks: [
    { agent: "scout", task: "one" }, { agent: "reviewer", task: "two" },
  ] }, undefined, undefined, pi.ctx);
  const second = pi.tool().execute("two", { tasks: [{ agent: "planner", task: "queued" }] }, undefined, undefined, pi.ctx);
  await waitUntil(() => started === 2);
  await pi.commands.get("plan")!("", pi.ctx);
  const results = await Promise.all([first, second]);
  assert.equal(peak, 2);
  assert.equal(started, 2);
  assert.equal(running, 0);
  assert.equal(pi.active().includes("subagent"), false);
  for (const result of results.flatMap((value) => value.details.results)) assert.equal(result.status, "cancelled");
  await assert.rejects(pi.tool().execute("blocked", { tasks: [{ agent: "scout", task: "blocked" }] }, undefined, undefined, pi.ctx), /plan mode/);
  await pi.commands.get("plan")!("", pi.ctx);
  assert.equal(pi.active().includes("subagent"), true);
  await pi.emit("session_shutdown");
});

test("legacy plan snapshots restore newly hidden subagent without enabling excluded bash", async () => {
  const pi = mockPi({} as ParentContext);
  pi.api.appendEntry("plan-mode", {
    enabled: true,
    toolsBeforePlanMode: ["read", "edit", "write", "codemode", "git"],
  });
  await pi.emit("session_start");
  assert.equal(pi.active().includes("subagent"), false);
  await pi.commands.get("plan")!("", pi.ctx);
  assert.equal(pi.active().includes("subagent"), true);
  assert.equal(pi.active().includes("bash"), false);
  await pi.emit("session_shutdown");
});

test("legacy migration does not enable a subagent that was not active on resume", async () => {
  const pi = mockPi({} as ParentContext);
  pi.api.setActiveTools(["read", "git"]);
  pi.api.appendEntry("plan-mode", { enabled: true, toolsBeforePlanMode: ["read", "git"] });
  await pi.emit("session_start");
  await pi.commands.get("plan")!("", pi.ctx);
  assert.deepEqual(pi.active(), ["read", "git"]);
  await pi.emit("session_shutdown");
});

test("new plan snapshots record policy and preserve intentionally disabled subagent on resume", async () => {
  const original = mockPi({} as ParentContext);
  original.api.setActiveTools(["read", "git"]);
  await original.commands.get("plan")!("", original.ctx);
  const state = original.ctx.sessionManager.getBranch().at(-1);
  assert.ok(state?.type === "custom");
  const data = state.data as { disabledTools: string[] };
  assert.ok(data.disabledTools.includes("subagent"));

  const resumed = mockPi({} as ParentContext);
  resumed.api.appendEntry("plan-mode", state.data);
  await resumed.emit("session_start");
  await resumed.commands.get("plan")!("", resumed.ctx);
  assert.deepEqual(resumed.active(), ["read", "git"]);
  await original.emit("session_shutdown");
  await resumed.emit("session_shutdown");
});

test("tree navigation restores newcomers using the same plan snapshot merge", async () => {
  const pi = mockPi({} as ParentContext);
  pi.api.appendEntry("plan-mode", { enabled: true, toolsBeforePlanMode: ["read", "git"] });
  await pi.emit("session_start");
  // Another enabled legacy branch also lacks subagent in its saved snapshot.
  pi.api.appendEntry("plan-mode", { enabled: true, toolsBeforePlanMode: ["read", "git"] });
  await pi.emit("session_tree");
  assert.equal(pi.active().includes("subagent"), false);
  pi.api.appendEntry("plan-mode", { enabled: false });
  await pi.emit("session_tree");
  assert.ok(pi.active().includes("subagent"));
  assert.equal(pi.active().includes("bash"), false);
  await pi.emit("session_shutdown");
});

test("parent abort and shutdown drain running jobs and reject work after shutdown", async () => {
  let started = 0;
  const context = await parent((_model, _transcript, options) => {
    started++;
    const stream = createAssistantMessageEventStream();
    options?.signal?.addEventListener("abort", () => deliver(stream, answer("", "aborted")), { once: true });
    return stream;
  });
  for (const reason of ["abort", "shutdown"]) {
    const pi = mockPi(context);
    const controller = new AbortController();
    const target = started + 1;
    const pending = pi.tool().execute(reason, { tasks: [{ agent: "scout", task: reason }] }, controller.signal, undefined, pi.ctx);
    await waitUntil(() => started === target);
    if (reason === "abort") controller.abort();
    else await pi.emit("session_shutdown");
    assert.equal((await pending).details.results[0].status, "cancelled");
    await pi.emit("session_shutdown");
    await assert.rejects(pi.tool().execute("late", { tasks: [{ agent: "scout", task: "late" }] }, undefined, undefined, pi.ctx), /shutting down/);
  }
});

test("SDK Git factory retains read-only command validation and PATH-based execution", async () => {
  const tool = createGitReadonlyTool();
  const context = { cwd: process.cwd() } as ExtensionToolContext;
  const status = await tool.execute("status", { operation: "status" }, undefined, undefined, context);
  assert.equal(status.isError, false);
  assert.equal(status.details.exitCode, 0);
  await assert.rejects(tool.execute("push", { operation: "push" } as never, undefined, undefined, context), /unsupported operation/);
});

test("strict task validation and bounded UTF-8 output with a recoverable full answer", async () => {
  for (const input of [
    { tasks: [] }, { tasks: [{ agent: "worker", task: "edit" }] },
    { tasks: [{ agent: "__proto__", task: "bad" }] },
    { tasks: [{ agent: "scout", task: " " }] },
    { tasks: [{ agent: "scout", task: "x", cwd: "/tmp" }] },
    { tasks: Array.from({ length: 9 }, () => ({ agent: "scout", task: "x" })) },
  ]) assert.throws(() => validateTasks(input as never));
  const output = "日本語\n".repeat(3000);
  const result: TaskResult = { id: "long", agent: "scout", status: "completed", output, turns: 1, usage: emptyUsage() };
  await boundOutput(result);
  assert.ok(Buffer.byteLength(result.output) < 4500);
  assert.ok(result.output.split("\n").length < 190);
  assert.ok(result.fullOutputPath);
  try {
    assert.equal(await readFile(result.fullOutputPath, "utf8"), output);
  } finally {
    await rm(join(result.fullOutputPath, ".."), { recursive: true, force: true });
  }
});

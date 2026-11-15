import assert from "node:assert/strict";
import { test } from "node:test";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import {
  createAgentSession, createCodemodeExtension, DefaultResourceLoader,
  ModelRuntime, SessionManager, SettingsManager,
} from "@earendil-works/pi-coding-agent";
import { installBashSandbox } from "../index.ts";
import { createState } from "../state.ts";

test("codemode bash reaches the sandbox shell, while write stays a local Pi tool", { timeout: 30_000 }, async () => {
  const cwd = await mkdtemp(join(tmpdir(), "pi-codemode-sandbox-"));
  const shell = join(cwd, "nono-bash");
  await writeFile(shell, "#!/bin/sh\nprintf 'nested sandbox\\n'\n");
  await chmod(shell, 0o755);
  const nested: string[] = [];
  const state = createState();
  const model = {
    id: "mock", name: "Mock", api: "openai-completions", provider: "sandbox-test",
    baseUrl: "https://must-not-be-contacted.invalid", reasoning: false, input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 100_000, maxTokens: 1000,
  } as const;
  const runtime = await ModelRuntime.create({
    modelsPath: null, refreshOnCreate: false,
    credentials: { read: async () => undefined, list: async () => [], modify: async () => {}, delete: async () => {} },
  });
  let turns = 0;
  runtime.registerNativeProvider({
    id: model.provider, name: "Offline sandbox test", getModels: () => [{ ...model, input: ["text"] }],
    auth: { apiKey: { name: "test", resolve: async () => ({ auth: { apiKey: "not-a-real-key" } }) } },
    stream: () => { throw new Error("Unexpected stream API"); },
    streamSimple: () => {
      const stream = createAssistantMessageEventStream();
      const script = `
        const values = await Promise.all([
          tools.bash({ command: "echo hi" }),
          tools.write({ path: "local-write.txt", content: "written by pi" }),
        ]);
        text(values[0].output);`;
      const first = turns++ === 0;
      const message: any = {
        role: "assistant", content: first ? [{ type: "toolCall", id: "cm", name: "codemode", arguments: { code: script } }] : [{ type: "text", text: "done" }],
        api: model.api, provider: model.provider, model: model.id, timestamp: Date.now(),
        stopReason: first ? "toolUse" : "stop",
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
      };
      stream.push({ type: "start", partial: message });
      stream.push({ type: "done", reason: message.stopReason, message });
      stream.end();
      return stream;
    },
  });
  await runtime.refresh({ allowNetwork: false, providers: [model.provider] });
  const settings = SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false }, cacheWarming: "off" });
  const loader = new DefaultResourceLoader({
    cwd, agentDir: join(cwd, "agent"), settingsManager: settings,
    noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true, noContextFiles: true,
    disabledBuiltinExtensions: ["mcp"],
    extensionFactories: [
      createCodemodeExtension({ models: false }),
      (pi) => {
        installBashSandbox(pi, state, shell);
        pi.on("tool_call", (event) => { if (event.parentToolCallId) nested.push(event.toolName); });
      },
    ],
  });
  let session: Awaited<ReturnType<typeof createAgentSession>>["session"] | undefined;
  try {
    await loader.reload();
    assert.deepEqual(loader.getExtensions().errors, []);
    ({ session } = await createAgentSession({
      cwd, agentDir: join(cwd, "agent"), model: runtime.getModel(model.provider, model.id), modelRuntime: runtime,
      settingsManager: settings, resourceLoader: loader, sessionManager: SessionManager.inMemory(cwd),
      tools: ["bash", "write", "codemode"],
    }));
    await session.bindExtensions({ mode: "json" });
    assert.equal(state.shell, shell);
    await session.prompt("Run the offline tool test");
    assert.deepEqual(nested.sort(), ["bash", "write"]);
    assert.equal(await readFile(join(cwd, "local-write.txt"), "utf8"), "written by pi");
    const result = session.messages.find((message) => message.role === "toolResult" && message.toolName === "codemode");
    assert.match(JSON.stringify(result), /nested sandbox/);
  } finally {
    session?.dispose();
    await rm(cwd, { recursive: true, force: true });
  }
});

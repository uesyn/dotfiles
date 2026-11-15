import type { AssistantMessage, CredentialStore, Usage } from "@earendil-works/pi-ai";
import {
  createAgentSession,
  createExtensionRuntime,
  getAgentDir,
  loadProjectContextFiles,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  type AgentSession,
  type ExtensionContext,
  type ResourceLoader,
} from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { createAstGrepTool } from "../ast-grep/index.ts";
import { createGitReadonlyTool } from "../git-readonly/index.ts";
import { applyPromptModifier, parseConfig } from "../systemp-prompt-modifier/index.ts";
import { agentPrompt, type AgentName } from "./agents.ts";

export type ParentContext = Pick<ExtensionContext, "cwd" | "model" | "thinkingLevel" | "modelRegistry">;
export type ChildSession = Pick<AgentSession, "prompt" | "subscribe" | "abort" | "dispose">;
export type TaskStatus = "queued" | "running" | "completed" | "failed" | "cancelled" | "timed_out" | "turn_limit";

export interface TaskResult {
  id: string;
  agent: AgentName;
  status: TaskStatus;
  output: string;
  activity?: string;
  fullOutputPath?: string;
  turns: number;
  usage: Usage;
}

export function emptyUsage(): Usage {
  return {
    input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
  };
}

export function addUsage(total: Usage, usage: Usage): void {
  for (const key of ["input", "output", "cacheRead", "cacheWrite", "totalTokens"] as const) {
    total[key] += usage[key];
  }
  for (const key of ["cacheWrite1h", "reasoning"] as const) {
    if (usage[key] !== undefined) total[key] = (total[key] ?? 0) + usage[key];
  }
  for (const key of ["input", "output", "cacheRead", "cacheWrite", "total"] as const) {
    total.cost[key] += usage.cost[key];
  }
}

// Children do not need their own credentials. All requests are delegated to the
// parent's public registry, preserving dynamic providers and serialized OAuth
// refresh without accessing ModelRegistry's private runtime or copying secrets.
const noCredentials: CredentialStore = {
  read: async () => undefined,
  list: async () => [],
  modify: async () => { throw new Error("Child credential writes are disabled"); },
  delete: async () => { throw new Error("Child credential writes are disabled"); },
};

function taskRequestOptions<T extends { signal?: AbortSignal }>(
  options: T | undefined,
  signal: AbortSignal,
) {
  // abort() during SDK prompt preflight has no active run to stop. Gate every
  // request, and preserve API-specific option types while replacing auth.
  signal.throwIfAborted();
  return Object.assign({}, options, {
    apiKey: undefined,
    headers: undefined,
    env: undefined,
    transformHeaders: undefined,
    signal: options?.signal ? AbortSignal.any([signal, options.signal]) : signal,
  });
}

export async function createChildSession(
  parent: ParentContext,
  agent: AgentName,
  signal: AbortSignal,
): Promise<ChildSession> {
  const model = parent.model;
  if (!model) throw new Error("No model selected");
  // Virtual model routing belongs to the parent runtime and is not exposed by
  // ExtensionContext. Do not silently choose a different physical model.
  if (model.api === "pi-virtual") throw new Error("Subagents require a physical model, not a virtual model");
  signal.throwIfAborted();

  const runtime = await ModelRuntime.create({
    credentials: noCredentials,
    modelsPath: null,
    refreshOnCreate: false,
    signal,
  });
  runtime.registerNativeProvider({
    id: model.provider,
    name: model.provider,
    getModels: () => [model],
    auth: {
      apiKey: {
        name: "Parent session authentication",
        // This only marks the bridge as usable. The parent resolves real auth
        // inside stream/streamSimple (its availability snapshot can lag behind
        // provider registration, so do not gate requests on that snapshot).
        check: async () => ({ type: "api_key", source: "parent session" }),
        resolve: async () => ({ auth: {} }),
      },
    },
    // Auth is resolved at request time by the parent, never by the bridge.
    stream: (requestModel, context, options) =>
      parent.modelRegistry.stream(requestModel, context, taskRequestOptions(options, signal)),
    streamSimple: (requestModel, context, options) =>
      parent.modelRegistry.streamSimple(requestModel, context, taskRequestOptions(options, signal)),
  });

  let prompt = agentPrompt(agent);
  try {
    const config = parseConfig(await readFile(join(homedir(), ".pi", "agent", "system-prompt-modifier.json"), "utf8"));
    prompt = applyPromptModifier(prompt, config.models[`${model.provider}/${model.id}`] ?? {});
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
  signal.throwIfAborted();

  // A custom loader avoids even evaluating project/global extensions, package
  // configuration, SYSTEM.md, prompt templates, skills, and MCP startup code.
  const contextFiles = loadProjectContextFiles({ cwd: parent.cwd, agentDir: getAgentDir() });
  const loader: ResourceLoader = {
    getExtensions: () => ({ extensions: [], errors: [], runtime: createExtensionRuntime() }),
    getSkills: () => ({ skills: [], diagnostics: [] }),
    getPrompts: () => ({ prompts: [], diagnostics: [] }),
    getThemes: () => ({ themes: [], diagnostics: [] }),
    getAgentsFiles: () => ({ agentsFiles: contextFiles }),
    getSystemPrompt: () => prompt,
    getSystemPromptSource: () => undefined,
    getAppendSystemPrompt: () => [],
    getAppendSystemPromptSources: () => [],
    extendResources: () => {},
    reload: async () => {},
  };
  const { session } = await createAgentSession({
    cwd: parent.cwd,
    model,
    thinkingLevel: parent.thinkingLevel ?? "off",
    modelRuntime: runtime,
    sessionManager: SessionManager.inMemory(parent.cwd),
    settingsManager: SettingsManager.inMemory({
      compaction: { enabled: false },
      retry: { enabled: false, provider: { maxRetries: 0 } },
      cacheWarming: "off",
    }),
    resourceLoader: loader,
    tools: ["read", "grep", "find", "ls", "git", "ast_grep"],
    customTools: [createGitReadonlyTool(), createAstGrepTool()],
  });
  return session;
}

export async function runTask(
  result: TaskResult,
  task: string,
  parent: ParentContext,
  parentSignal: AbortSignal,
  onChange: () => void,
  options: {
    timeoutMs?: number;
    maxTurns?: number;
    createSession?: typeof createChildSession;
  } = {},
): Promise<void> {
  const controller = new AbortController();
  const signal = AbortSignal.any([parentSignal, controller.signal]);
  const timer = setTimeout(() => controller.abort("timed_out"), options.timeoutMs ?? 300_000);
  let session: ChildSession | undefined;
  let unsubscribe: (() => void) | undefined;
  let lastMessage: AssistantMessage | undefined;
  let abortPromise: Promise<void> | undefined;
  const abort = () => {
    if (session && !abortPromise) {
      // Keep the scheduler slot until prompt/abort have really settled. A timer
      // cannot forcibly terminate an uncooperative SDK/provider in this process.
      abortPromise = session.abort().catch(() => {});
    }
  };

  result.status = "running";
  onChange();
  signal.addEventListener("abort", abort, { once: true });
  try {
    signal.throwIfAborted();
    session = await (options.createSession ?? createChildSession)(parent, result.agent, signal);
    if (signal.aborted) {
      abort();
      signal.throwIfAborted();
    }
    unsubscribe = session.subscribe((event) => {
      if (event.type === "tool_execution_start") {
        result.activity = event.toolName;
        onChange();
      }
      if (event.type !== "message_end" || event.message.role !== "assistant") return;
      lastMessage = event.message;
      result.turns++;
      addUsage(result.usage, lastMessage.usage);
      if (result.turns >= (options.maxTurns ?? 20) && lastMessage.stopReason === "toolUse") {
        controller.abort("turn_limit");
      }
      onChange();
    });
    // Prefixing also prevents task text from being interpreted as a slash command.
    await session.prompt(`Delegated task:\n\n${task}`, { expandPromptTemplates: false });
    if (signal.aborted) throw signal.reason;
    if (!lastMessage || lastMessage.stopReason !== "stop") {
      throw new Error(lastMessage?.errorMessage ?? `Subagent ended without a complete answer (${lastMessage?.stopReason ?? "no response"})`);
    }
    result.status = "completed";
  } catch (error) {
    result.status = signal.aborted
      ? signal.reason === "timed_out" ? "timed_out"
        : signal.reason === "turn_limit" ? "turn_limit" : "cancelled"
      : "failed";
    result.output = error instanceof Error ? error.message : String(error);
  } finally {
    clearTimeout(timer);
    signal.removeEventListener("abort", abort);
    await abortPromise;
    unsubscribe?.();
    session?.dispose();
    const answer = lastMessage?.content
      .filter((part) => part.type === "text")
      .map((part) => part.text)
      .join("\n")
      .trim();
    if (answer) result.output = result.output ? `${result.output}\n\nPartial answer:\n${answer}` : answer;
    if (result.status === "completed" && !result.output) {
      result.status = "failed";
      result.output = "Subagent returned an empty answer";
    }
    result.activity = undefined;
    onChange();
  }
}

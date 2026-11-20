import { StringEnum } from "@earendil-works/pi-ai";
import {
  truncateHead,
  type AgentToolResult,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Type, type Static } from "typebox";
import { isPlanModeEnabled, PLAN_MODE_EVENT } from "../plan-mode/state.ts";
import { AGENTS, type AgentName } from "./agents.ts";
import { addUsage, emptyUsage, runTask, type TaskResult } from "./runner.ts";
import { Scheduler } from "./scheduler.ts";

export const SubagentSchema = Type.Object({
  tasks: Type.Array(Type.Object({
    agent: StringEnum(["scout", "planner", "reviewer"] as const),
    task: Type.String({ minLength: 1, maxLength: 16_000 }),
  }, { additionalProperties: false }), { minItems: 1, maxItems: 8 }),
}, { additionalProperties: false });

type SubagentInput = Static<typeof SubagentSchema>;
export type SubagentDetails = { results: TaskResult[] };

export function validateTasks(input: SubagentInput): void {
  if (!input || Object.keys(input).some((key) => key !== "tasks") ||
    !Array.isArray(input.tasks) || input.tasks.length < 1 || input.tasks.length > 8) {
    throw new Error("Expected 1–8 subagent tasks");
  }
  for (const task of input.tasks) {
    if (!task || Object.keys(task).some((key) => key !== "agent" && key !== "task") ||
      typeof task.agent !== "string" || !Object.hasOwn(AGENTS, task.agent) || typeof task.task !== "string" ||
      !task.task.trim() || task.task.length > 16_000) {
      throw new Error("Each task needs a known read-only agent and 1–16000 characters of task text");
    }
  }
}

export async function boundOutput(result: TaskResult): Promise<void> {
  const truncated = truncateHead(result.output, { maxBytes: 4096, maxLines: 180 });
  if (!truncated.truncated) return;
  try {
    const dir = await mkdtemp(join(tmpdir(), "pi-subagent-"));
    const path = join(dir, "result.md");
    await writeFile(path, result.output, { encoding: "utf8", mode: 0o600 });
    result.fullOutputPath = path;
    result.output = `${truncated.content}\n\n[Output truncated. Full answer: ${path}]`;
  } catch {
    result.output = `${truncated.content}\n\n[Output truncated; full answer could not be saved.]`;
  }
}

function formatResults(results: TaskResult[], partial = false): string {
  return results.map((result, index) => {
    const header = `${index + 1}. ${result.agent} [${result.status}] (${result.id})`;
    return partial
      ? `${header}${result.activity ? ` — ${result.activity}` : ""}`
      : `${header}\n${result.output}`;
  }).join("\n\n");
}

export default function subagentExtension(pi: ExtensionAPI): void {
  const scheduler = new Scheduler();
  const calls = new Map<AbortController, Promise<void>>();
  let closed = false;
  const cancelAll = (reason: string) => {
    for (const controller of calls.keys()) controller.abort(reason);
  };
  const unsubscribePlan = pi.events.on(PLAN_MODE_EVENT, (data) => {
    if ((data as { enabled?: unknown } | undefined)?.enabled === true) cancelAll("Plan mode enabled");
  });

  pi.on("session_tree", () => cancelAll("Session branch changed"));
  pi.on("session_shutdown", async () => {
    closed = true;
    unsubscribePlan();
    cancelAll("Parent session shut down");
    await Promise.allSettled([...calls.values()]);
  });

  pi.registerTool({
    name: "subagent",
    label: "Subagent (read-only)",
    // Orchestration belongs here, not inside codemode scripts or other tools.
    exposure: "model-only",
    description:
      "Delegate 1–8 independent read-only tasks to scout (code discovery), planner (implementation planning), or reviewer (adversarial code review). " +
      "Runs at most five SDK sessions concurrently across calls. Children inherit the current model/thinking level, not conversation history. " +
      "Only read/grep/find/ls/read-only git/read-only ast_grep; no edits, bash, MCP, recursive delegation, or worktrees. " +
      "Each task is limited to 5 minutes and 20 model turns; output to 4 KiB/180 lines with full truncated answers saved to a private temporary file. " +
      "Returns task statuses and answers in input order, preserving partial failures. Disabled in plan mode.",
    promptSnippet: "Delegate independent code discovery, planning, or review to read-only subagents (five concurrent).",
    promptGuidelines: [
      "Use subagent with a tasks array to parallelize independent investigations; give each task enough background and a clear deliverable.",
      "Subagent children share the working tree, not the conversation. Parent owns implementation and test execution; do not edit relevant files while subagents inspect them.",
    ],
    parameters: SubagentSchema,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: false },

    async execute(_toolCallId, input, signal, onUpdate, ctx): Promise<AgentToolResult<SubagentDetails>> {
      validateTasks(input);
      if (closed) throw new Error("Subagent extension is shutting down");
      if (isPlanModeEnabled(ctx)) throw new Error("Subagent is disabled in plan mode");
      if (!ctx.model) throw new Error("No model selected");
      if (ctx.model.api === "pi-virtual") throw new Error("Subagents require a physical model, not a virtual model");
      const parent = {
        cwd: ctx.cwd,
        model: structuredClone(ctx.model),
        thinkingLevel: ctx.thinkingLevel ?? pi.getThinkingLevel(),
        modelRegistry: ctx.modelRegistry,
      };
      const controller = new AbortController();
      const callSignal = signal ? AbortSignal.any([signal, controller.signal]) : controller.signal;
      let finish!: () => void;
      calls.set(controller, new Promise<void>((resolve) => { finish = resolve; }));
      const results: TaskResult[] = input.tasks.map((task) => ({
        id: randomUUID(), agent: task.agent as AgentName, status: "queued", output: "", turns: 0, usage: emptyUsage(),
      }));
      const update = () => {
        try {
          onUpdate?.({
            content: [{ type: "text", text: formatResults(results, true) }],
            details: { results: structuredClone(results).map((result) => ({ ...result, output: "" })) },
          });
        } catch {
          // A detached UI must not turn a successful child into a failed job.
        }
      };

      try {
        update();
        await Promise.all(input.tasks.map(async (task, index) => {
          const result = results[index];
          try {
            await scheduler.run(async () => {
              if (isPlanModeEnabled(ctx)) throw new Error("Subagent is disabled in plan mode");
              await runTask(result, task.task, parent, callSignal, update);
            }, callSignal);
          } catch (error) {
            result.status = callSignal.aborted ? "cancelled" : "failed";
            result.output = error instanceof Error ? error.message : String(error);
          }
          await boundOutput(result);
          update();
        }));
        const usage = emptyUsage();
        for (const result of results) addUsage(usage, result.usage);
        return {
          content: [{ type: "text", text: formatResults(results) }],
          details: { results },
          usage,
          isError: results.some((result) => result.status !== "completed"),
        };
      } finally {
        calls.delete(controller);
        finish();
      }
    },
  });
}

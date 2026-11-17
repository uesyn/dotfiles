import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isPlanModeEnabled, PLAN_MODE_EVENT } from "../plan-mode/state.ts";

export function parseConfig(text: string): string[] {
  const value = JSON.parse(text.replace(/^\uFEFF/, ""));
  if (!value || typeof value !== "object" || Array.isArray(value) ||
      !Array.isArray(value.disabledByDefault) ||
      !value.disabledByDefault.every((name: unknown) => typeof name === "string" && name.length > 0)) {
    throw new Error("disabledByDefault must be an array of non-empty tool names");
  }
  return value.disabledByDefault;
}

async function loadConfig(): Promise<string[]> {
  try {
    return parseConfig(await readFile(join(homedir(), ".pi", "agent", "tool-toggle.json"), "utf8"));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw error;
  }
}

export default function toolToggle(pi: ExtensionAPI, readConfig = loadConfig): void {
  const disabled = new Set<string>();

  function reconcile(): void {
    const active = pi.getActiveTools();
    const allowed = active.filter((name) => !disabled.has(name));
    if (allowed.length !== active.length) pi.setActiveTools(allowed);
  }

  const unsubscribePlan = pi.events.on(PLAN_MODE_EVENT, reconcile);
  pi.on("session_shutdown", async () => { unsubscribePlan(); });
  pi.on("session_tree", async () => { reconcile(); });
  // Late-registered tools can become active after session_start.
  pi.on("before_agent_start", async () => { reconcile(); });

  pi.on("session_start", async (_event, ctx) => {
    disabled.clear();
    try {
      for (const name of await readConfig()) disabled.add(name);
    } catch (error) {
      ctx.ui.notify(`Invalid tool-toggle configuration: ${error instanceof Error ? error.message : String(error)}`, "warning");
    }
    // Plan mode restores its own snapshot during startup; do not override it.
    if (!isPlanModeEnabled(ctx)) {
      const names = pi.getAllTools()
        .filter((tool) => !tool.exposure || tool.exposure === "direct" || tool.exposure === "model-only")
        .map((tool) => tool.name);
      pi.setActiveTools([...new Set([...pi.getActiveTools(), ...names])].filter((name) => !disabled.has(name)));
    } else {
      reconcile();
    }
  });

  pi.on("tool_call", async (event) => {
    if (disabled.has(event.toolName)) {
      return { block: true, reason: `Tool ${event.toolName} is disabled by tool-toggle.` };
    }
  });

  pi.registerCommand("tool", {
    description: "Show or toggle tools for this session",
    getArgumentCompletions: (prefix) => {
      const matches = pi.getAllTools()
        .filter((tool) => tool.exposure !== "hidden" && tool.name.startsWith(prefix))
        .map((tool) => ({ value: tool.name, label: tool.name }));
      return matches.length ? matches : null;
    },
    handler: async (args, ctx) => {
      reconcile();
      const name = args.trim();
      const tools = pi.getAllTools().filter((tool) => tool.exposure !== "hidden");
      const active = pi.getActiveTools();
      if (!name) {
        const lines = tools.map((tool) =>
          `${active.includes(tool.name) && !disabled.has(tool.name) ? "enabled" : "disabled"}: ${tool.name}`,
        ).sort();
        ctx.ui.notify(lines.length ? lines.join("\n") : "No tools available.", "info");
        return;
      }
      if (!tools.some((tool) => tool.name === name)) {
        ctx.ui.notify(`Unknown tool: ${name}`, "error");
        return;
      }
      if (isPlanModeEnabled(ctx)) {
        ctx.ui.notify("Leave plan mode before changing tools.", "warning");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("Wait for the agent to finish before changing tools.", "warning");
        return;
      }
      if (active.includes(name) && !disabled.has(name)) {
        disabled.add(name);
        pi.setActiveTools(active.filter((tool) => tool !== name));
        ctx.ui.notify(`Disabled: ${name}`, "info");
      } else {
        disabled.delete(name);
        pi.setActiveTools([...new Set([...active, name])]);
        ctx.ui.notify(`Enabled: ${name}`, "info");
      }
    },
  });
}

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const DISABLED_TOOLS = new Set([
  "bash",
  "edit",
  "write",
]);

type PlanModeState = {
  enabled: boolean;
  toolsBeforePlanMode?: string[];
};

export default function planMode(pi: ExtensionAPI): void {
  let enabled = false;
  let toolsBeforePlanMode: string[] | undefined;

  function updateStatus(ctx: ExtensionContext): void {
    if (!ctx.hasUI) {
      return;
    }

    if (enabled) {
      ctx.ui.setStatus(
        "plan-mode",
        ctx.ui.theme.fg("warning", "⏸ PLAN"),
      );
    } else {
      ctx.ui.setStatus("plan-mode", undefined);
    }
  }

  function persist(): void {
    pi.appendEntry("plan-mode", {
      enabled,
      toolsBeforePlanMode,
    } satisfies PlanModeState);
  }

  function enable(ctx: ExtensionContext): void {
    if (enabled) {
      return;
    }

    toolsBeforePlanMode = pi.getActiveTools();

    const tools = toolsBeforePlanMode.filter(
      (tool) => !DISABLED_TOOLS.has(tool),
    );

    pi.setActiveTools(tools);

    enabled = true;

    updateStatus(ctx);
    persist();

    if (ctx.hasUI) {
      ctx.ui.notify(
        "Plan mode enabled: bash, write, and edit tools are disabled.",
        "info",
      );
    }
  }

  function disable(ctx: ExtensionContext): void {
    if (!enabled) {
      return;
    }

    if (toolsBeforePlanMode) {
      pi.setActiveTools(toolsBeforePlanMode);
    }

    toolsBeforePlanMode = undefined;
    enabled = false;

    updateStatus(ctx);
    persist();

    if (ctx.hasUI) {
      ctx.ui.notify(
        "Plan mode disabled: normal tool access restored.",
        "info",
      );
    }
  }

  function toggle(ctx: ExtensionContext): void {
    if (enabled) {
      disable(ctx);
    } else {
      enable(ctx);
    }
  }

  pi.registerCommand("plan", {
    description: "Toggle read-only plan mode",
    handler: async (_args, ctx) => {
      toggle(ctx);
    },
  });

  pi.registerShortcut("ctrl+p", {
    description: "Toggle read-only plan mode",
    handler: (ctx) => {
      toggle(ctx);
    },
  });

  /*
   * Bash is removed from the active tool list above, but keep this guard for
   * tool calls that were already in flight when plan mode was enabled.
   */
  pi.on("tool_call", async (event) => {
    if (!enabled || !DISABLED_TOOLS.has(event.toolName)) {
      return;
    }

    return {
      block: true,
      reason:
        "Plan mode is active. This tool is disabled. " +
        "Use /plan to leave plan mode.",
    };
  });

  pi.on("before_agent_start", async (event) => {
    if (!enabled) {
      return;
    }

    return {
      systemPrompt:
        event.systemPrompt +
        `

# PLAN MODE

You are currently in PLAN MODE.

Your task is to investigate, reason, and produce an implementation plan.

Rules:

- Do not modify files.
- Do not create files.
- Do not delete files.
- Do not run commands that modify the working tree or system state.
- Inspect the existing codebase as much as necessary.
- Use available read-only tools to verify assumptions.
- Do not implement the requested changes yet.

When ready, provide a concrete implementation plan.

Prefer plans that identify:
- relevant files and components
- existing behavior
- changes required
- important implementation details
- risks or edge cases
- validation/tests

The user can leave PLAN MODE with /plan.
`,
    };
  });

  /*
   * Restore mode when resuming/reloading a session.
   */
  pi.on("session_start", async (_event, ctx) => {
    const entries = ctx.sessionManager.getEntries();

    const entry = entries
      .filter(
        (entry: {
          type: string;
          customType?: string;
        }) =>
          entry.type === "custom" &&
          entry.customType === "plan-mode",
      )
      .pop() as
      | {
          data?: PlanModeState;
        }
      | undefined;

    if (entry?.data) {
      enabled = entry.data.enabled ?? false;
      toolsBeforePlanMode =
        entry.data.toolsBeforePlanMode;
    }

    if (enabled) {
      /*
       * Do not blindly use the persisted list as the active
       * list here. New custom/MCP tools may have appeared since
       * the previous session.
       *
       * Remove only tools that are explicitly forbidden.
       */
      const active = pi.getActiveTools();

      pi.setActiveTools(
        active.filter(
          (tool) => !DISABLED_TOOLS.has(tool),
        ),
      );
    }

    updateStatus(ctx);
  });
}

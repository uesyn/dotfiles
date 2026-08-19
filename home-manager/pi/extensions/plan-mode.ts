import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const DISABLED_TOOLS = new Set([
  "bash",
  "edit",
  "write",
]);

type PlanModeState = {
  enabled: boolean;
  toolsBeforePlanMode?: string[];
};

function isPlanModeState(value: unknown): value is PlanModeState {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  const candidate = value as {
    enabled?: unknown;
    toolsBeforePlanMode?: unknown;
  };

  return (
    typeof candidate.enabled === "boolean" &&
    (candidate.toolsBeforePlanMode === undefined ||
      (Array.isArray(candidate.toolsBeforePlanMode) &&
        candidate.toolsBeforePlanMode.every(
          (tool): tool is string => typeof tool === "string",
        )))
  );
}

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

    /*
     * Restore the pre-plan tool list, but keep tools that other extensions
     * activated while plan mode was on. This mirrors session restoration,
     * which avoids blindly reapplying a stale list.
     */
    const restored = toolsBeforePlanMode ?? [];
    const kept = pi
      .getActiveTools()
      .filter(
        (tool) => !restored.includes(tool) && !DISABLED_TOOLS.has(tool),
      );

    pi.setActiveTools([...restored, ...kept]);

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

  pi.registerShortcut("ctrl+l", {
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

  pi.on("before_agent_start", async () => {
    if (!enabled) {
      return;
    }

    return {
      message: {
        customType: "plan-mode-context",
        content: `[PLAN MODE ACTIVE]
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
        display: false,
      },
    };
  });

  /*
   * Remove stale plan-mode instructions from the LLM context once plan mode
   * is disabled. The injected [PLAN MODE ACTIVE] custom messages are
   * persisted in the session, so without this filter the model would keep
   * seeing the instructions after /plan and still act as if plan mode were
   * active.
   *
   * Only the injected custom messages and user messages carrying the marker
   * are removed. Assistant and tool messages are left untouched so
   * toolCall/toolResult pairs stay intact; the model's own plan-mode-era
   * replies remain in history, which is fine once the authoritative
   * instructions are gone.
   */
  pi.on("context", async (event) => {
    if (enabled) {
      return;
    }

    return {
      messages: event.messages.filter((message) => {
        const msg = message as {
          customType?: string;
          content?: unknown;
        };

        // Injected plan-mode instructions (custom messages).
        if (msg.customType === "plan-mode-context") {
          return false;
        }

        // Only user messages may carry the marker; leave assistant/tool
        // results untouched so toolCall/toolResult pairs stay intact.
        if (message.role !== "user") {
          return true;
        }

        const content = msg.content;
        if (typeof content === "string") {
          return !content.includes("[PLAN MODE ACTIVE]");
        }
        if (Array.isArray(content)) {
          return !content.some(
            (block) =>
              (block as { type?: string }).type === "text" &&
              typeof (block as { text?: unknown }).text === "string" &&
              (block as { text: string }).text.includes(
                "[PLAN MODE ACTIVE]",
              ),
          );
        }
        return true;
      }),
    };
  });

  function getLastPlanModeState(
    ctx: ExtensionContext,
  ): PlanModeState | undefined {
    let lastState: PlanModeState | undefined;

    /*
     * Session entries form a tree. Only inspect the current branch so that
     * an entry from an abandoned branch cannot override the current state.
     * getBranch() returns entries from the root to the current leaf.
     */
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom") {
        continue;
      }

      const customEntry = entry as {
        customType?: string;
        data?: unknown;
      };

      if (
        customEntry.customType === "plan-mode" &&
        isPlanModeState(customEntry.data)
      ) {
        lastState = customEntry.data;
      }
    }

    return lastState;
  }

  function restoreState(ctx: ExtensionContext): void {
    const savedState = getLastPlanModeState(ctx);
    const nextEnabled = savedState?.enabled ?? false;
    const nextToolsBeforePlanMode =
      savedState?.toolsBeforePlanMode === undefined
        ? undefined
        : [...savedState.toolsBeforePlanMode];
    const wasEnabled = enabled;
    const previousToolsBeforePlanMode = toolsBeforePlanMode;
    const activeTools = pi.getActiveTools();

    if (nextEnabled) {
      /*
       * On a fresh process, use the persisted pre-plan tool list. When
       * switching branches in an existing process, this also replaces the
       * snapshot used when leaving plan mode.
       */
      toolsBeforePlanMode =
        nextToolsBeforePlanMode ??
        (wasEnabled ? previousToolsBeforePlanMode : activeTools);
      enabled = true;

      // Preserve newly available tools, but always remove plan-mode tools.
      pi.setActiveTools(
        activeTools.filter((tool) => !DISABLED_TOOLS.has(tool)),
      );
    } else {
      if (wasEnabled) {
        /*
         * A tree navigation from an enabled branch to a disabled branch must
         * restore the tools that were active before plan mode was enabled.
         * Keep tools added by other extensions while plan mode was active.
         */
        const restored = previousToolsBeforePlanMode ?? [];
        const kept = activeTools.filter(
          (tool) =>
            !restored.includes(tool) && !DISABLED_TOOLS.has(tool),
        );
        pi.setActiveTools([...restored, ...kept]);
      }

      enabled = false;
      toolsBeforePlanMode = undefined;
    }

    updateStatus(ctx);
  }

  /*
   * Restore mode when starting/resuming/reloading a session. The session
   * manager has already loaded the session before session_start fires.
   */
  pi.on("session_start", async (_event, ctx) => {
    restoreState(ctx);
  });

  /*
   * Keep the in-memory mode and active tools in sync when /tree changes the
   * current branch without restarting pi.
   */
  pi.on("session_tree", async (_event, ctx) => {
    restoreState(ctx);
  });
}

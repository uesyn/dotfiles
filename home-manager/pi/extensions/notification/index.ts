import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const FLAG_NAME = "notification";
const STATE_TYPE = "notification";
const STATUS_KEY = "notification";
const OSC_NOTIFICATION = "\x1b]777;notify;Pi;処理が完了しました\x07";

type NotificationState = {
  enabled: boolean;
};

function isNotificationState(value: unknown): value is NotificationState {
  return (
    typeof value === "object" &&
    value !== null &&
    "enabled" in value &&
    typeof value.enabled === "boolean"
  );
}

function getPersistedState(ctx: ExtensionContext): boolean | undefined {
  const branch = ctx.sessionManager.getBranch();

  for (let index = branch.length - 1; index >= 0; index -= 1) {
    const entry = branch[index];
    if (entry?.type !== "custom" || entry.customType !== STATE_TYPE) {
      continue;
    }

    if (isNotificationState(entry.data)) {
      return entry.data.enabled;
    }
  }

  return undefined;
}

function updateStatus(ctx: ExtensionContext, enabled: boolean): void {
  if (!ctx.hasUI) {
    return;
  }

  ctx.ui.setStatus(
    STATUS_KEY,
    enabled ? ctx.ui.theme.fg("accent", "🔔 NOTIFY") : undefined,
  );
}

function sendNotification(): void {
  try {
    process.stdout.write(OSC_NOTIFICATION);
  } catch {
    // Notifications are best-effort and must not affect the agent run.
  }
}

export default function notificationExtension(pi: ExtensionAPI): void {
  pi.registerFlag(FLAG_NAME, {
    description: "Enable OSC 777 notifications when Pi finishes processing",
    type: "boolean",
    default: false,
  });

  let enabled = pi.getFlag(FLAG_NAME) === true;
  let agentRunActive = false;

  function persistState(): void {
    pi.appendEntry(STATE_TYPE, { enabled });
  }

  function setEnabled(ctx: ExtensionContext, next: boolean): void {
    if (enabled !== next) {
      enabled = next;
      persistState();
    }

    updateStatus(ctx, enabled);
  }

  function toggle(ctx: ExtensionContext): void {
    setEnabled(ctx, !enabled);
    ctx.ui.notify(
      `Notifications ${enabled ? "enabled" : "disabled"}.`,
      "info",
    );
  }

  pi.registerCommand("notification", {
    description: "Toggle OSC 777 notifications when Pi finishes processing",
    handler: async (args, ctx) => {
      if (args.trim()) {
        ctx.ui.notify("Usage: /notification", "warning");
        return;
      }

      toggle(ctx);
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    const persistedState = getPersistedState(ctx);
    const enabledByFlag = pi.getFlag(FLAG_NAME) === true;

    enabled = persistedState ?? enabledByFlag;
    updateStatus(ctx, enabled);
  });

  pi.on("agent_start", async () => {
    agentRunActive = true;
  });

  pi.on("agent_settled", async (_event, ctx) => {
    const shouldNotify =
      agentRunActive &&
      enabled &&
      ctx.mode === "tui" &&
      process.stdout.isTTY === true;

    agentRunActive = false;

    if (shouldNotify) {
      sendNotification();
    }
  });
}

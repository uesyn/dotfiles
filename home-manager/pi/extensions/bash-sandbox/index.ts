import {
  createBashToolDefinition,
  createLocalBashOperations,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { shell as bakedShell } from "./endpoint.ts";
import { createState, initialize, sandboxShell, status, type State } from "./state.ts";

export default function bashSandbox(pi: ExtensionAPI): void {
  installBashSandbox(pi, createState());
}

// `shell` is for offline tests only; production always uses the path Home
// Manager baked into `endpoint.ts`, never a model/project setting.
export function installBashSandbox(pi: ExtensionAPI, state: State, shell: string = bakedShell): void {
  const cwd = process.cwd();
  // The sandboxed shell is a Nix-store wrapper that execs nono. Pi keeps its own
  // spawn/timeout/process-tree handling because only shellPath changes.
  const operations = () => createLocalBashOperations({ shellPath: sandboxShell(state) });
  pi.registerTool({
    ...createBashToolDefinition(cwd),
    // Async so a fail-closed `operations()` throw surfaces as a rejected tool call.
    async execute(id, args, signal, onUpdate, ctx) {
      // `getSettings()` deep-clones the settings tree, so read it once.
      const settings = pi.getSettings();
      const tool = createBashToolDefinition(ctx.cwd, {
        // Pi's built-in tool gets these from settings; keep them on override.
        shellPath: settings.shellPath,
        commandPrefix: settings.shellCommandPrefix,
        ...(state.enabled ? { operations: operations() } : {}),
      });
      return tool.execute(id, args, signal, onUpdate, ctx);
    },
  });
  pi.on("user_bash", () => {
    if (!state.enabled) return;
    return { operations: operations() };
  });
  // The statusline text and color come from one place, so the command and
  // session_start cannot disagree about the current state.
  const showStatus = (ctx: Pick<ExtensionContext, "hasUI" | "ui">) => {
    if (!ctx.hasUI) return;
    const color = !state.enabled ? "warning" : state.shell ? "muted" : "error";
    ctx.ui.setStatus("bash-sandbox", ctx.ui.theme.fg(color, status(state)));
  };
  const notifyKind = () => (!state.enabled ? "warning" : state.shell ? "info" : "error");
  pi.registerCommand("sandbox", {
    description: "Show shell sandbox status, enable it, or explicitly disable it (on/off)",
    async handler(args, ctx) {
      const action = args.trim();
      if (!action) {
        const detail = state.enabled && !state.shell ? `\n${state.error}` : "";
        ctx.ui.notify(`Shell sandbox: ${status(state)}${detail}\nbash and !/!! ${state.enabled ? "run through nono" : "run WITHOUT nono"}. write/edit, read tools, MCP and other extensions are not covered.`, notifyKind());
        return;
      }
      if (action !== "on" && action !== "off") { ctx.ui.notify("Usage: /sandbox [on|off]", "warning"); return; }
      if (!ctx.isIdle() || ctx.hasPendingMessages()) {
        ctx.ui.notify("Wait until Pi is idle before switching the shell sandbox.", "warning");
        return;
      }
      if (action === "off") {
        state.enabled = false;
      } else {
        await initialize(state, shell);
      }
      showStatus(ctx);
      ctx.ui.notify(`Shell sandbox: ${status(state)}`, notifyKind());
    },
  });
  pi.on("session_start", async (_event, ctx) => {
    await initialize(state, shell);
    showStatus(ctx);
    if (ctx.hasUI && !state.shell) ctx.ui.notify(`${status(state)}: ${state.error}`, "error");
  });
  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setStatus("bash-sandbox", undefined);
  });
}

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export const PLAN_MODE_EVENT = "dotfiles:plan-mode";

export function isPlanModeEnabled(ctx: ExtensionContext): boolean {
  let enabled = false;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "custom" || entry.customType !== "plan-mode") continue;
    const data = entry.data as { enabled?: unknown } | undefined;
    if (typeof data?.enabled === "boolean") enabled = data.enabled;
  }
  return enabled;
}

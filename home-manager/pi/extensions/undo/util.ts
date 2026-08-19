/** Small shared helpers. */

/** Truncate a string with an ellipsis. */
export function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return `${text.slice(0, Math.max(0, max - 1))}…`;
}

/** Extract display text from a message content (string or content blocks). */
export function contentText(
  content: string | Array<{ type?: string; text?: unknown }>,
): string {
  if (typeof content === "string") return content;
  return content
    .filter((block) => block.type === "text" && typeof block.text === "string")
    .map((block) => block.text as string)
    .join("\n");
}

export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Render a short list of file paths for dialogs/notifications. */
export function listPaths(paths: string[], max = 8): string {
  const shown = paths.slice(0, max);
  const lines = shown.map((p) => `  ${p}`);
  if (paths.length > max) {
    lines.push(`  … and ${paths.length - max} more`);
  }
  return lines.join("\n");
}

/** Summarize a diff for display. */
export function summarizeDiff(changes: Array<{ status: string; path: string }>): string {
  const byStatus: Record<string, number> = { M: 0, A: 0, D: 0, T: 0 };
  for (const c of changes) byStatus[c.status] = (byStatus[c.status] ?? 0) + 1;
  const parts: string[] = [];
  if ((byStatus.M ?? 0) > 0) parts.push(`${byStatus.M ?? 0} modified`);
  if ((byStatus.A ?? 0) > 0) parts.push(`${byStatus.A ?? 0} added`);
  if ((byStatus.D ?? 0) > 0) parts.push(`${byStatus.D ?? 0} deleted`);
  if ((byStatus.T ?? 0) > 0) parts.push(`${byStatus.T ?? 0} typechanged`);
  if (parts.length === 0) return "no file changes";
  return parts.join(", ");
}

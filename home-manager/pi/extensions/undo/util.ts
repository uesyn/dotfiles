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

/**
 * last-model — remember the model and thinking level in use.
 *
 * Every model or thinking-level change is recorded, and a fresh session
 * (`startup` or `new`) starts with the recorded combination, unless the
 * invocation already chose one with `--model`, `--models` or `--thinking`.
 * A resumed or forked session already restores its own model from history, and
 * a reload keeps the running session's, so those reasons are left alone.
 *
 * This is deliberately independent of favorite-models: favorites are presets
 * the user manages, while the model used last is observation. Because the
 * record is written on every change, selecting a favorite records it too, so a
 * favorite needs no "last selected" bookkeeping of its own.
 *
 * State lives in `<agentDir>/last-model.json` (override with
 * PI_LAST_MODEL_FILE), which stays writable even when settings.json is managed
 * read-only (e.g. by home-manager).
 */

import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

/** Thinking levels pi supports, in canonical order. */
const THINKING_LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
] as const;
type ThinkingLevel = (typeof THINKING_LEVELS)[number];

const THINKING_LEVEL_SET: ReadonlySet<string> = new Set(THINKING_LEVELS);

type LastModel = {
  provider: string;
  model: string;
  /** Level active with this model; absent in files written before it was recorded. */
  thinkingLevel?: ThinkingLevel;
};

function lastModelPath(): string {
  return (
    process.env.PI_LAST_MODEL_FILE?.trim() || join(getAgentDir(), "last-model.json")
  );
}

function recordKey(record: LastModel): string {
  return `${record.provider}/${record.model}:${record.thinkingLevel ?? ""}`;
}

function isThinkingLevel(value: unknown): value is ThinkingLevel {
  return typeof value === "string" && THINKING_LEVEL_SET.has(value);
}

/** Return undefined for anything that is not a complete provider/model pair. */
function sanitize(value: unknown): LastModel | undefined {
  if (typeof value !== "object" || value === null) return undefined;
  const raw = value as Record<string, unknown>;
  if (typeof raw.provider !== "string" || raw.provider.length === 0) return undefined;
  if (typeof raw.model !== "string" || raw.model.length === 0) return undefined;

  const record: LastModel = { provider: raw.provider, model: raw.model };
  if (isThinkingLevel(raw.thinkingLevel)) record.thinkingLevel = raw.thinkingLevel;
  return record;
}

let writeQueue: Promise<void> = Promise.resolve();

function saveLastModel(record: LastModel): Promise<void> {
  const path = lastModelPath();

  writeQueue = writeQueue
    .then(async () => {
      const temporaryPath = `${path}.${process.pid}.tmp`;
      await mkdir(dirname(path), { recursive: true });
      await writeFile(temporaryPath, `${JSON.stringify(record, null, 2)}\n`, {
        encoding: "utf8",
        mode: 0o600,
      });
      await rename(temporaryPath, path);
    })
    .catch((error) => {
      console.error(`last-model: failed to write ${path}:`, error);
    });

  return writeQueue;
}

async function loadLastModel(): Promise<LastModel | undefined> {
  const path = lastModelPath();

  try {
    return sanitize(JSON.parse(await readFile(path, "utf8")) as unknown);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      console.error(`last-model: failed to read ${path}:`, error);
    }
    return undefined;
  }
}

function describe(record: LastModel): string {
  const level = record.thinkingLevel ? ` (thinking: ${record.thinkingLevel})` : "";
  return `${record.provider}/${record.model}${level}`;
}

/**
 * Flags that pick a model or thinking level for this invocation. Pi resolves
 * them before `session_start`, so the record must not override them: a
 * `pi --model x` run has to use `x`, not whatever was used last.
 */
function selectionPinnedOnCommandLine(): boolean {
  const flags = ["--model", "--models", "--thinking"];
  return process.argv
    .slice(2)
    .some((arg) => flags.includes(arg) || flags.some((flag) => arg.startsWith(`${flag}=`)));
}

export default function lastModelExtension(pi: ExtensionAPI): void {
  /** Key of the record already on disk, so repeated events skip the write. */
  let written: string | undefined;
  /** Set while restore() applies the record, so its own events do not record. */
  let restoring = false;

  /** The combination in use right now, or undefined when no model is selected. */
  function currentRecord(ctx: ExtensionContext): LastModel | undefined {
    const model = ctx.model;
    if (!model) return undefined;
    return {
      provider: model.provider,
      model: model.id,
      thinkingLevel: pi.getThinkingLevel(),
    };
  }

  async function remember(ctx: ExtensionContext): Promise<void> {
    if (restoring) return;
    const record = currentRecord(ctx);
    if (!record) return;

    const key = recordKey(record);
    if (key === written) return;
    written = key;
    await saveLastModel(record);
  }

  async function restore(ctx: ExtensionContext): Promise<void> {
    if (selectionPinnedOnCommandLine()) return;

    const record = await loadLastModel();
    if (!record) return;

    const model = ctx.modelRegistry.find(record.provider, record.model);
    if (!model) {
      // Keep the record: the provider may be configured again later.
      ctx.ui.notify(`Last model not found in the registry: ${describe(record)}`, "warning");
      return;
    }

    restoring = true;
    try {
      const current = ctx.model;
      const isCurrent =
        current !== undefined &&
        current.provider === model.provider &&
        current.id === model.id;
      if (!isCurrent && !(await pi.setModel(model))) {
        ctx.ui.notify(`No API key for last model: ${describe(record)}`, "error");
        return;
      }
      // Pi clamps the level when the model does not support it.
      if (record.thinkingLevel) pi.setThinkingLevel(record.thinkingLevel);
    } finally {
      restoring = false;
      // Adopt the state pi actually settled on, so an unchanged selection does
      // not rewrite the file.
      const actual = currentRecord(ctx);
      if (actual) written = recordKey(actual);
    }
  }

  pi.on("session_start", async (event, ctx) => {
    // A resumed or forked session restores its own model from history and a
    // reload keeps the running session's, so only fresh sessions take the record.
    if (event.reason !== "startup" && event.reason !== "new") return;
    await restore(ctx);
  });

  pi.on("model_select", async (_event, ctx) => {
    await remember(ctx);
  });

  pi.on("thinking_level_select", async (_event, ctx) => {
    await remember(ctx);
  });
}

import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ThinkingLevel = string;

type LastModel = {
  provider: string;
  model: string;
  thinkingLevel?: ThinkingLevel;
};

const statePath =
  process.env.PI_LAST_MODEL_FILE ??
  join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"), "pi", "last-model.json");

function isLastModel(value: unknown): value is LastModel {
  if (typeof value !== "object" || value === null) return false;

  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.provider === "string" &&
    candidate.provider.length > 0 &&
    typeof candidate.model === "string" &&
    candidate.model.length > 0 &&
    (candidate.thinkingLevel === undefined || typeof candidate.thinkingLevel === "string")
  );
}

async function loadLastModel(): Promise<LastModel | undefined> {
  try {
    const value: unknown = JSON.parse(await readFile(statePath, "utf8"));
    return isLastModel(value) ? value : undefined;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      console.error(`Failed to read ${statePath}:`, error);
    }
    return undefined;
  }
}

let writeQueue = Promise.resolve();

function saveLastModel(model: LastModel): Promise<void> {
  writeQueue = writeQueue
    .then(async () => {
      const directory = dirname(statePath);
      const temporaryPath = `${statePath}.${process.pid}.tmp`;

      await mkdir(directory, { recursive: true });
      await writeFile(temporaryPath, `${JSON.stringify(model)}\n`, {
        encoding: "utf8",
        mode: 0o600,
      });
      await rename(temporaryPath, statePath);
    })
    .catch((error) => {
      console.error(`Failed to write ${statePath}:`, error);
    });

  return writeQueue;
}

export default function lastModelExtension(pi: ExtensionAPI) {
  // Ignore selection events emitted while pi restores the initial model.
  // The startup/new-session handler below applies our own state first.
  let initialized = false;

  pi.on("session_start", async (event, ctx) => {
    if (event.reason === "startup" || event.reason === "new") {
      const lastModel = await loadLastModel();

      if (lastModel) {
        const model = ctx.modelRegistry.find(lastModel.provider, lastModel.model);

        if (!model) {
          ctx.ui.notify(`Last model not found: ${lastModel.provider}/${lastModel.model}`, "warning");
        } else {
          const currentModel = ctx.model;
          let modelRestored =
            currentModel?.provider === lastModel.provider && currentModel?.id === lastModel.model;

          if (!modelRestored) {
            modelRestored = await pi.setModel(model);
            if (!modelRestored) {
              ctx.ui.notify(`No API key for ${lastModel.provider}`, "warning");
            }
          }

          if (modelRestored && lastModel.thinkingLevel) {
            pi.setThinkingLevel(lastModel.thinkingLevel as Parameters<ExtensionAPI["setThinkingLevel"]>[0]);
          }
        }
      } else if (ctx.model) {
        // Also remember the initial model and thinking level on the first run.
        await saveLastModel({
          provider: ctx.model.provider,
          model: ctx.model.id,
          thinkingLevel: pi.getThinkingLevel(),
        });
      }
    }

    initialized = true;
  });

  pi.on("model_select", async (event) => {
    if (!initialized) return;

    await saveLastModel({
      provider: event.model.provider,
      model: event.model.id,
      thinkingLevel: pi.getThinkingLevel(),
    });
  });

  pi.on("thinking_level_select", async (event, ctx) => {
    if (!initialized || !ctx.model) return;

    await saveLastModel({
      provider: ctx.model.provider,
      model: ctx.model.id,
      thinkingLevel: event.level,
    });
  });

  pi.on("session_shutdown", async () => {
    await writeQueue;
  });
}

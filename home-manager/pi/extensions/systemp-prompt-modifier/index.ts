import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const CONFIG_PATH = join(
  homedir(),
  ".pi",
  "agent",
  "system-prompt-modifier.json",
);
const STATUS_ID = "systemp-prompt-modifier";
const STATUS_TEXT = "prompt-modifier: active";

export type PromptModifier = {
  prepend?: string;
  append?: string;
};

export type PromptConfig = {
  models: Record<string, PromptModifier>;
};

function validateConfig(value: unknown): PromptConfig {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("The config root must be an object");
  }

  const root = value as Record<string, unknown>;
  if (
    typeof root.models !== "object" ||
    root.models === null ||
    Array.isArray(root.models)
  ) {
    throw new Error("The models field must be an object");
  }

  const models = Object.entries(root.models).map(([modelName, rawModifier]) => {
    if (
      typeof rawModifier !== "object" ||
      rawModifier === null ||
      Array.isArray(rawModifier)
    ) {
      throw new Error(`Configuration for ${modelName} must be an object`);
    }

    const modifier: PromptModifier = {};
    for (const [field, rawText] of Object.entries(rawModifier)) {
      if (field !== "prepend" && field !== "append") {
        throw new Error(`Unknown prompt field for ${modelName}: ${field}`);
      }
      if (typeof rawText !== "string") {
        throw new Error(`${modelName}.${field} must be a string`);
      }
      modifier[field] = rawText;
    }

    return [modelName, modifier] as const;
  });

  return { models: Object.fromEntries(models) };
}

export function parseConfig(text: string): PromptConfig {
  return validateConfig(JSON.parse(text.replace(/^\uFEFF/, "")));
}

export function applyPromptModifier(
  systemPrompt: string,
  modifier: PromptModifier,
): string {
  const parts = [modifier.prepend, systemPrompt, modifier.append]
    .filter((part): part is string => part !== undefined && part.trim() !== "")
    .map((part) => part.trim());

  return parts.join("\n");
}

let lastConfigError: string | undefined;

function setModifierStatus(ctx: ExtensionContext, active: boolean): void {
  if (!ctx.hasUI) return;
  ctx.ui.setStatus(STATUS_ID, active ? STATUS_TEXT : undefined);
}

function hasModifierContent(modifier: PromptModifier | undefined): boolean {
  return (
    modifier !== undefined &&
    [modifier.prepend, modifier.append].some(
      (part) => part !== undefined && part.trim() !== "",
    )
  );
}

async function loadConfig(): Promise<PromptConfig | undefined> {
  try {
    const config = parseConfig(await readFile(CONFIG_PATH, "utf8"));
    lastConfigError = undefined;
    return config;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      lastConfigError = undefined;
      return undefined;
    }

    const message = error instanceof Error ? error.message : String(error);
    const errorKey = `${CONFIG_PATH}: ${message}`;
    if (lastConfigError !== errorKey) {
      console.error(`Failed to load ${CONFIG_PATH}: ${message}`);
      lastConfigError = errorKey;
    }
    return undefined;
  }
}

export default function systempPromptModifier(pi: ExtensionAPI): void {
  const refreshStatus = async (
    ctx: ExtensionContext,
    model: { provider: string; id: string } | undefined,
  ): Promise<void> => {
    if (!model) {
      setModifierStatus(ctx, false);
      return;
    }

    const config = await loadConfig();
    setModifierStatus(
      ctx,
      hasModifierContent(config?.models[`${model.provider}/${model.id}`]),
    );
  };

  pi.on("session_start", async (_event, ctx) => {
    await refreshStatus(ctx, ctx.model);
  });

  pi.on("model_select", async (event, ctx) => {
    await refreshStatus(ctx, event.model);
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (!ctx.model) {
      setModifierStatus(ctx, false);
      return undefined;
    }

    const config = await loadConfig();
    if (!config) {
      setModifierStatus(ctx, false);
      return undefined;
    }

    const modelName = `${ctx.model.provider}/${ctx.model.id}`;
    const modifier = config.models[modelName];
    const active = hasModifierContent(modifier);
    setModifierStatus(ctx, active);

    if (!active || !modifier) return undefined;

    return {
      systemPrompt: applyPromptModifier(event.systemPrompt, modifier),
    };
  });
}

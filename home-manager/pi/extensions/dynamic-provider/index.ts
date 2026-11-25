import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BASE_URL_ENV = "PI_OPENAI_DYNAMIC_BASE_URL";
const MODEL_ENV = "PI_OPENAI_DYNAMIC_MODEL";
const API_KEY_ENV = "PI_OPENAI_DYNAMIC_API_KEY";

// pi does not fill in an extension model definition, so every required field
// has to be stated here. These are the same defaults pi applies to a
// models.json entry; change them when the endpoint has a smaller window.
const CONTEXT_WINDOW = 128_000;
const MAX_TOKENS = 16_384;

export default function dynamicProvider(pi: ExtensionAPI): void {
  const baseUrl = process.env[BASE_URL_ENV]?.trim();
  const model = process.env[MODEL_ENV]?.trim();

  if (!baseUrl || !model) {
    return;
  }

  pi.registerProvider("dynamic", {
    name: "Dynamic",
    baseUrl,
    api: "openai-completions",
    apiKey: `$${API_KEY_ENV}`,
    models: [
      {
        id: model,
        name: model,
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: CONTEXT_WINDOW,
        maxTokens: MAX_TOKENS,
      },
    ],
  });
}

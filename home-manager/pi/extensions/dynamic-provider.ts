import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BASE_URL_ENV = "PI_OPENAI_DYNAMIC_BASE_URL";
const MODEL_ENV = "PI_OPENAI_DYNAMIC_MODEL";
const API_KEY_ENV = "PI_OPENAI_DYNAMIC_API_KEY";

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
    models: [{ id: model }],
  });
}

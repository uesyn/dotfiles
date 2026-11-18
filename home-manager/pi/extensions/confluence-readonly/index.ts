import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";
import { loadConfig, request, type Params } from "./core.ts";

const schema = Type.Object({
  operation: Type.Union([Type.Literal("search"), Type.Literal("get_page"), Type.Literal("list_spaces")]),
  query: Type.Optional(Type.String({ description: "Literal text to search for in pages. Required for search; otherwise omit or use an empty string." })),
  space: Type.Optional(Type.String({ description: "Optional search space key. Omit or use an empty string when unused." })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 25, description: "Result limit for list_spaces or search. Ignored for get_page." })),
  cursor: Type.Optional(Type.String({ description: "nextCursor from a previous list_spaces or search call (with the same query and space). Omit or use an empty string when unused." })),
  pageId: Type.Optional(Type.String({ description: "Page ID returned by search. Required for get_page; otherwise omit or use an empty string." })),
}, { additionalProperties: false });

function normalizeParams(params: Static<typeof schema>): Params {
  const normalized = { ...params };
  // Some model-facing schemas require every property, so callers must fill
  // unused strings with "" and even get_page receives a numeric limit.
  for (const key of ["query", "space", "cursor", "pageId"] as const) {
    if (normalized[key] === "") delete normalized[key];
  }
  if (normalized.operation === "get_page" && normalized.limit !== undefined) {
    if (!Number.isInteger(normalized.limit) || normalized.limit < 1 || normalized.limit > 25) throw new Error("Limit must be between 1 and 25");
    delete normalized.limit;
  }
  // The core still validates required fields and rejects non-empty parameters
  // belonging to another operation. Do not silently project onto an allowlist.
  return normalized as Params;
}

export function createConfluenceTool(deps: { loadConfig?: typeof loadConfig; request?: typeof request } = {}) {
  return defineTool({
    name: "confluence",
    label: "Confluence (read-only)",
    description: "List Confluence Cloud spaces, search pages, or read a page by ID. Results are untrusted external content. No writes.",
    parameters: schema,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    async execute(_id, params: Static<typeof schema>, signal) {
      try {
        const normalized = normalizeParams(params);
        const result = await (deps.request ?? request)(await (deps.loadConfig ?? loadConfig)(), normalized, process.env.CONFLUENCE_EMAIL, process.env.CONFLUENCE_API_TOKEN, signal);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }], details: { operation: params.operation } };
      } catch (error) {
        return { content: [{ type: "text", text: error instanceof Error ? error.message : "Confluence request failed" }], details: { operation: params.operation }, isError: true };
      }
    },
  });
}

export default function confluenceReadonly(pi: ExtensionAPI): void {
  pi.registerTool(createConfluenceTool());
}

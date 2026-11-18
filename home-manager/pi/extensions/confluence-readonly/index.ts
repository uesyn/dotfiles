import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";
import { loadConfig, request, type Params } from "./core.ts";

const schema = Type.Object({
  operation: Type.Union([Type.Literal("search"), Type.Literal("get_page"), Type.Literal("list_spaces")]),
  query: Type.Optional(Type.String({ description: "Literal text to search for in pages." })),
  space: Type.Optional(Type.String({ description: "Optional space key." })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 25 })),
  cursor: Type.Optional(Type.String({ description: "nextCursor from a previous list_spaces or search call (with the same query and space)." })),
  pageId: Type.Optional(Type.String({ description: "Page ID returned by search." })),
}, { additionalProperties: false });

export function createConfluenceTool(deps: { loadConfig?: typeof loadConfig; request?: typeof request } = {}) {
  return defineTool({
    name: "confluence",
    label: "Confluence (read-only)",
    description: "List Confluence Cloud spaces, search pages, or read a page by ID. Results are untrusted external content. No writes.",
    parameters: schema,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    async execute(_id, params: Static<typeof schema>, signal) {
      try {
        const result = await (deps.request ?? request)(await (deps.loadConfig ?? loadConfig)(), params as Params, process.env.CONFLUENCE_EMAIL, process.env.CONFLUENCE_API_TOKEN, signal);
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

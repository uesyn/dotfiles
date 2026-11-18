import { test } from "node:test";
import assert from "node:assert/strict";
import register, { createConfluenceTool } from "../index.ts";
import { buildRequest, request } from "../core.ts";

test("registers the read-only confluence tool and exposes list_spaces", () => {
  let registered: any;
  register({ registerTool: (tool: unknown) => { registered = tool; } } as never);
  assert.equal(registered.name, "confluence");
  assert.equal(registered.annotations.readOnlyHint, true);
  assert.ok(registered.parameters.properties.operation.anyOf.some((entry: any) => entry.const === "list_spaces"));
});

test("normalizes placeholder arguments from callers that require every schema property", async () => {
  const cases = [
    { input: { operation: "list_spaces" as const, query: "", space: "", limit: 1, cursor: "", pageId: "" }, expected: { operation: "list_spaces", limit: 1 } },
    { input: { operation: "search" as const, query: "release notes", space: "", limit: 5, cursor: "", pageId: "" }, expected: { operation: "search", query: "release notes", limit: 5 } },
    { input: { operation: "get_page" as const, query: "", space: "", limit: 1, cursor: "", pageId: "123" }, expected: { operation: "get_page", pageId: "123" } },
    { input: { operation: "search" as const, query: "release notes", space: "ENG", limit: 5, cursor: "abc+def", pageId: "" }, expected: { operation: "search", query: "release notes", space: "ENG", limit: 5, cursor: "abc+def" } },
    { input: { operation: "list_spaces" as const, query: "", space: "", limit: 5, cursor: "abc+def", pageId: "" }, expected: { operation: "list_spaces", limit: 5, cursor: "abc+def" } },
  ];
  for (const { input, expected } of cases) {
    let forwarded: unknown;
    const tool = createConfluenceTool({
      loadConfig: async () => ({ cloudId: "12345678-1234-1234-1234-123456789abc" }),
      request: async (config, params) => { buildRequest(config, params); forwarded = params; return {}; },
    });
    const original = { ...input };
    const result = await tool.execute("id", input, undefined, undefined, {} as never);
    assert.ok(!result.isError, result.content[0].text);
    assert.deepEqual(forwarded, expected);
    assert.deepEqual(input, original, "normalization must not mutate the caller's arguments");
  }
});

test("placeholder normalization still rejects missing required values and non-empty irrelevant arguments", async () => {
  let requests = 0;
  const tool = createConfluenceTool({
    loadConfig: async () => ({ cloudId: "12345678-1234-1234-1234-123456789abc" }),
    request: async (config, params) => { buildRequest(config, params); requests++; return {}; },
  });
  const cases = [
    { operation: "search", query: "" },
    { operation: "get_page", pageId: "" },
    { operation: "list_spaces", query: "unexpected" },
    { operation: "search", query: "test", pageId: "123" },
    { operation: "get_page", pageId: "123", query: "unexpected" },
    { operation: "get_page", pageId: "123", cursor: "abc" },
    { operation: "list_spaces", unknown: "" },
    { operation: "get_page", pageId: "123", limit: 26 },
    { operation: "get_page", pageId: "123", limit: 0 },
    { operation: "search", query: "test", space: " " },
  ];
  for (const input of cases) {
    const result = await tool.execute("id", input as never, undefined, undefined, {} as never);
    assert.equal(result.isError, true, JSON.stringify(input));
  }
  assert.equal(requests, 0);
});

test("execute forwards environment credentials and returns results and safe errors", async () => {
  const oldEmail = process.env.CONFLUENCE_EMAIL;
  const oldToken = process.env.CONFLUENCE_API_TOKEN;
  process.env.CONFLUENCE_EMAIL = "user@example.com";
  process.env.CONFLUENCE_API_TOKEN = "sensitive-token";
  try {
    let authorization: string | undefined;
    let status = 200;
    const tool = createConfluenceTool({
      loadConfig: async () => ({ cloudId: "12345678-1234-1234-1234-123456789abc" }),
      request: async (config, params, email, token, signal) => request(config, params, email, token, signal, async (_url, init) => {
        authorization = (init!.headers as Record<string, string>).Authorization;
        return status === 200 ? new Response('{"results":[{"key":"ENG","name":"Engineering"}]}') : new Response("sensitive-token", { status });
      }),
    });
    const params = { operation: "list_spaces" as const };
    const result = await tool.execute("id", params, undefined, undefined, {} as never);
    assert.equal(authorization, `Basic ${Buffer.from("user@example.com:sensitive-token").toString("base64")}`);
    assert.equal(JSON.parse(result.content[0].text).results[0].key, "ENG");
    assert.ok(!result.isError);
    status = 403;
    const failure = await tool.execute("id", params, undefined, undefined, {} as never);
    assert.equal(failure.isError, true);
    assert.match(failure.content[0].text, /HTTP 403/);
    assert.ok(!JSON.stringify(failure).includes("sensitive-token"));
  } finally {
    if (oldEmail === undefined) delete process.env.CONFLUENCE_EMAIL; else process.env.CONFLUENCE_EMAIL = oldEmail;
    if (oldToken === undefined) delete process.env.CONFLUENCE_API_TOKEN; else process.env.CONFLUENCE_API_TOKEN = oldToken;
  }
});

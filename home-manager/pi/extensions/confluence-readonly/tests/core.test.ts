import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildRequest, formatResult, loadConfig, request } from "../core.ts";

const scoped = { cloudId: "12345678-1234-1234-1234-123456789abc" };
const search = { operation: "search" as const, query: "release notes", space: "ENG", limit: 5 };

test("loads missing, valid and malformed configuration", async () => {
  const dir = await mkdtemp(join(tmpdir(), "confluence-test-"));
  const home = process.env.HOME;
  process.env.HOME = dir;
  try {
    assert.deepEqual(await loadConfig(), { cloudId: null });
    const path = join(dir, ".pi", "agent", "confluence-readonly.json");
    await mkdir(join(dir, ".pi", "agent"), { recursive: true });
    await writeFile(path, JSON.stringify(scoped));
    assert.deepEqual(await loadConfig(), scoped);
    for (const input of ["not json", '{}', '{"cloudId":1}']) {
      await writeFile(path, input);
      await assert.rejects(loadConfig, /Invalid Confluence configuration/);
    }
  } finally {
    if (home === undefined) delete process.env.HOME; else process.env.HOME = home;
    await rm(dir, { recursive: true, force: true });
  }
});

test("builds fixed scoped endpoints", () => {
  const url = buildRequest(scoped, search);
  assert.equal(url.origin, "https://api.atlassian.com");
  assert.equal(url.pathname, `/ex/confluence/${scoped.cloudId}/wiki/rest/api/search`);
  assert.equal(url.searchParams.get("cql"), 'type = page AND text ~ "\\\"release notes\\\"" AND space = "ENG"');
  assert.equal(url.searchParams.get("limit"), "5");
  const page = buildRequest(scoped, { operation: "get_page", pageId: "123" });
  assert.equal(page.href, "https://api.atlassian.com/ex/confluence/12345678-1234-1234-1234-123456789abc/wiki/api/v2/pages/123?body-format=storage");
});

test("lists spaces with fixed endpoints and validated pagination", async () => {
  const params = { operation: "list_spaces" as const };
  const first = buildRequest(scoped, params);
  assert.equal(first.href, `https://api.atlassian.com/ex/confluence/${scoped.cloudId}/wiki/api/v2/spaces?limit=25`);
  const scopedUrl = buildRequest(scoped, { ...params, limit: 10, cursor: "abc+def" });
  assert.equal(scopedUrl.origin, "https://api.atlassian.com");
  assert.equal(scopedUrl.pathname, `/ex/confluence/${scoped.cloudId}/wiki/api/v2/spaces`);
  assert.equal(scopedUrl.searchParams.get("cursor"), "abc+def");
  assert.throws(() => buildRequest(scoped, { ...params, limit: 26 }));
  assert.throws(() => buildRequest(scoped, { ...params, cursor: "\n" }));
  assert.throws(() => buildRequest(scoped, { ...params, query: "unexpected" } as never));
  const result: any = await request(scoped, params, "user@example.com", "token", undefined, async () => new Response(JSON.stringify({
    results: [{ id: "12", key: "ENG", name: "Engineering", type: "global", status: "current", _links: { webui: "/spaces/ENG/overview" } }],
    _links: { base: "https://example.atlassian.net/wiki", next: "https://evil.invalid/?cursor=abc%2Bdef" },
  })));
  assert.deepEqual(result.results[0], { id: "12", key: "ENG", name: "Engineering", type: "global", status: "current", url: "https://example.atlassian.net/wiki/spaces/ENG/overview" });
  assert.equal(result.nextCursor, "abc+def");
  assert.equal(buildRequest(scoped, { ...params, cursor: result.nextCursor }).origin, "https://api.atlassian.com");
  assert.throws(() => formatResult(scoped, params, { results: {} }), /spaces response/);
});

test("rejects invalid cloud IDs and model inputs", () => {
  assert.throws(() => buildRequest({ cloudId: null }, search), /cloudId/);
  assert.throws(() => buildRequest({ cloudId: "../x" }, search), /cloudId/);
  assert.throws(() => buildRequest(scoped, { operation: "get_page", pageId: "../x" }));
  assert.throws(() => buildRequest(scoped, { ...search, space: 'x" OR type=blogpost' }));
  assert.throws(() => buildRequest(scoped, { ...search, limit: 26 }));
  assert.throws(() => buildRequest(scoped, { ...search, query: "a\nb" }));
  const cql = buildRequest(scoped, { ...search, query: 'x" OR type = blogpost' }).searchParams.get("cql")!;
  assert.ok(cql.includes('\\\\\\"'));
});

test("formats responses, bounds bodies and never follows result links", () => {
  const result: any = formatResult(scoped, search, { results: [{ content: { id: "12", space: { key: "ENG" } }, title: "hello", url: "//evil.invalid/x" }], _links: { next: "https://evil.invalid/x?cursor=abc%2Bdef" } });
  assert.equal(result.results[0].id, "12");
  assert.equal(result.results[0].url, undefined);
  assert.equal(result.nextCursor, "abc+def");
  assert.equal(buildRequest(scoped, { ...search, cursor: result.nextCursor }).origin, "https://api.atlassian.com");
  const page: any = formatResult(scoped, { operation: "get_page", pageId: "12" }, { id: "12", title: "Page", body: { storage: { value: "x".repeat(60001) } }, _links: { base: "https://example.atlassian.net/wiki", webui: "/wiki/spaces/E/pages/12" } });
  assert.equal(page.body.length, 60000);
  assert.equal(page.truncated, true);
  assert.equal(page.url, "https://example.atlassian.net/wiki/spaces/E/pages/12");
  const pageData = { body: { storage: { value: "body" } }, _links: { base: "https://docs.example.com/wiki", webui: "/spaces/E/pages/12" } };
  assert.equal((formatResult(scoped, { operation: "get_page", pageId: "12" }, pageData) as any).url, "https://docs.example.com/wiki/spaces/E/pages/12");
  for (const base of [undefined, "http://example.com", "https://user:pass@example.com/wiki", "https://example.com/unexpected"]) {
    assert.equal((formatResult(scoped, { operation: "get_page", pageId: "12" }, { ...pageData, _links: { ...pageData._links, base } }) as any).url, undefined);
  }
});

test("uses GET, basic auth, no redirects and bounds response", async () => {
  let seen: any;
  const mock: typeof fetch = async (input, init) => { seen = { input, init }; return new Response(JSON.stringify({ results: [] })); };
  await request(scoped, search, "user@example.com", "secret", undefined, mock);
  assert.equal(seen.init.method, "GET");
  assert.equal(seen.init.redirect, "error");
  assert.equal(seen.init.headers.Authorization, `Basic ${Buffer.from("user@example.com:secret").toString("base64")}`);
  await assert.rejects(() => request(scoped, search, "a", "token", undefined, async () => new Response("x".repeat(2 * 1024 * 1024 + 1))), /size limit/);
  await assert.rejects(() => request(scoped, search, "a", "token", undefined, async () => new Response("secret", { status: 401 })), /HTTP 401/);
  await assert.rejects(() => request(scoped, search, "a", "token", undefined, async () => { throw new Error("secret"); }), (e: Error) => !e.message.includes("secret"));
});

test("scoped pagination keeps fixed endpoints and search filters", async () => {
  for (const params of [search, { operation: "list_spaces" as const }]) {
    const calls: URL[] = [];
    const fetcher: typeof fetch = async (input) => {
      calls.push(new URL(String(input)));
      return new Response(JSON.stringify({ results: [], _links: calls.length === 1 ? { next: "https://evil.invalid/?cursor=a%2Bb%3D" } : {} }));
    };
    const first: any = await request(scoped, params, "user", "token", undefined, fetcher);
    await request(scoped, { ...params, cursor: first.nextCursor }, "user", "token", undefined, fetcher);
    assert.equal(calls[1].origin, "https://api.atlassian.com");
    assert.equal(calls[1].pathname, calls[0].pathname);
    assert.equal(calls[1].searchParams.get("cursor"), "a+b=");
    assert.equal(calls[1].searchParams.get("cql"), calls[0].searchParams.get("cql"));
    assert.equal(calls[1].searchParams.get("limit"), calls[0].searchParams.get("limit"));
  }
});

test("reports malformed responses and redacts HTTP and redirect errors", async () => {
  const params = { operation: "list_spaces" as const };
  await assert.rejects(() => request(scoped, params, "a", "secret", undefined, async () => new Response('{"results":{}}')), /Invalid Confluence spaces response/);
  await assert.rejects(() => request(scoped, params, "a", "secret", undefined, async () => new Response("not json")), /Invalid JSON/);
  await assert.rejects(() => request(scoped, params, "a", "secret", undefined, async () => new Response("secret", { status: 403 })), (e: Error) => /HTTP 403/.test(e.message) && !e.message.includes("secret"));
  await assert.rejects(() => request(scoped, params, "a", "secret", undefined, async () => { throw new TypeError("redirect to secret"); }), (e: Error) => /redirect error/.test(e.message) && !e.message.includes("secret"));
});

test("enforces response limit across chunks and cancels the stream", async () => {
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(1024 * 1024));
      controller.enqueue(new Uint8Array(1024 * 1024 + 1));
    },
    cancel() { cancelled = true; },
  });
  await assert.rejects(() => request(scoped, search, "a", "b", undefined, async () => new Response(stream)), /size limit/);
  assert.equal(cancelled, true);
});

test("cancels while reading the response stream", async () => {
  const controller = new AbortController();
  const pending = request(scoped, search, "a", "b", controller.signal, async (_url, init) => {
    const stream = new ReadableStream<Uint8Array>({
      start(streamController) {
        init!.signal!.addEventListener("abort", () => streamController.error(new Error("aborted")));
      },
    });
    queueMicrotask(() => controller.abort());
    return new Response(stream);
  });
  await assert.rejects(() => pending, /cancelled/);
});

test("times out a stalled request", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const pending = request(scoped, search, "a", "b", undefined, async (_url, init) =>
    await new Promise((_resolve, reject) => init!.signal!.addEventListener("abort", () => reject(new Error("aborted")))));
  const rejected = assert.rejects(pending, /timed out/);
  t.mock.timers.tick(30_000);
  await rejected;
});

test("cancels and checks credentials before requests", async () => {
  let called = false;
  const fetcher: typeof fetch = async () => { called = true; return new Response(); };
  await assert.rejects(() => request(scoped, search, undefined, undefined, undefined, fetcher), /CONFLUENCE_EMAIL/);
  const abort = new AbortController(); abort.abort();
  await assert.rejects(() => request(scoped, search, "a", "b", abort.signal, fetcher), /cancelled/);
  assert.equal(called, false);
  const controller = new AbortController();
  const pending = request(scoped, search, "a", "b", controller.signal, async (_url, init) => await new Promise((_resolve, reject) => init!.signal!.addEventListener("abort", () => reject(new Error("abort")))));
  controller.abort();
  await assert.rejects(() => pending, /cancelled/);
});

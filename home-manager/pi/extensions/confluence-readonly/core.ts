import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type Config = { cloudId: string | null };
export type Params = { operation: "search"; query: string; space?: string; limit?: number; cursor?: string } | { operation: "get_page"; pageId: string } | { operation: "list_spaces"; limit?: number; cursor?: string };
const MAX_RESPONSE = 2 * 1024 * 1024;
const MAX_BODY = 60_000;

export async function loadConfig(): Promise<Config> {
  try {
    const data = JSON.parse(await readFile(join(homedir(), ".pi", "agent", "confluence-readonly.json"), "utf8"));
    if (!data || typeof data !== "object" || Array.isArray(data) ||
        !(data.cloudId === null || typeof data.cloudId === "string")) throw new Error();
    return { cloudId: data.cloudId };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return { cloudId: null };
    throw new Error("Invalid Confluence configuration");
  }
}

export function buildRequest(config: Config, params: Params): URL {
  if (config.cloudId === null) throw new Error("Configure dotfiles.pi.confluence.cloudId for a scoped token");
  if (typeof config.cloudId !== "string" || !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(config.cloudId)) throw new Error("Invalid Confluence cloudId");
  const base = `https://api.atlassian.com/ex/confluence/${config.cloudId}`;
  if (params.operation === "get_page") {
    if (Object.keys(params).some((key) => !["operation", "pageId"].includes(key)) || !/^\d{1,30}$/.test(params.pageId)) throw new Error("Invalid pageId");
    const url = new URL(`${base}/wiki/api/v2/pages/${params.pageId}`);
    url.searchParams.set("body-format", "storage");
    return url;
  }
  if (params.operation !== "search" && params.operation !== "list_spaces") throw new Error("Invalid operation");
  const allowed = params.operation === "search" ? ["operation", "query", "space", "limit", "cursor"] : ["operation", "limit", "cursor"];
  if (Object.keys(params).some((key) => !allowed.includes(key))) throw new Error("Invalid operation parameters");
  if (params.limit !== undefined && (!Number.isInteger(params.limit) || params.limit < 1 || params.limit > 25)) throw new Error("Limit must be between 1 and 25");
  if (params.cursor !== undefined && (typeof params.cursor !== "string" || !params.cursor || params.cursor.length > 2048 || /[\x00-\x1f\x7f]/.test(params.cursor))) throw new Error("Invalid cursor");
  if (params.operation === "list_spaces") {
    const url = new URL(`${base}/wiki/api/v2/spaces`);
    url.searchParams.set("limit", String(params.limit ?? 25));
    if (params.cursor) url.searchParams.set("cursor", params.cursor);
    return url;
  }
  if (typeof params.query !== "string" || !params.query.trim() || params.query.length > 300 || /[\x00-\x1f\x7f]/.test(params.query)) throw new Error("Invalid search query");
  if (params.space !== undefined && !/^[a-zA-Z0-9_~-]{1,100}$/.test(params.space)) throw new Error("Invalid space key");
  // Escape both Lucene phrase syntax and the surrounding CQL string literal.
  const phrase = `"${params.query.trim().replace(/[\\"+\-!(){}\[\]^~*?:/|&]/g, "\\$&")}"`;
  let cql = `type = page AND text ~ ${JSON.stringify(phrase)}`;
  if (params.space) cql += ` AND space = ${JSON.stringify(params.space)}`;
  const url = new URL(`${base}/wiki/rest/api/search`);
  url.searchParams.set("cql", cql);
  url.searchParams.set("limit", String(params.limit ?? 10));
  if (params.cursor) url.searchParams.set("cursor", params.cursor);
  return url;
}

function pageLink(base: unknown, raw: unknown): string | undefined {
  if (typeof base !== "string" || base.length > 4096 || typeof raw !== "string" || raw.length > 4096 || !raw.startsWith("/") || raw.startsWith("//") || raw.includes("\\")) return undefined;
  try {
    const origin = new URL(base);
    if (origin.protocol !== "https:" || origin.username || origin.password || origin.search || origin.hash || !["/", "/wiki", "/wiki/"].includes(origin.pathname)) return undefined;
    // v2 links can be relative to the /wiki context. This URL is output only,
    // never a request destination; the base is untrusted response data.
    const url = new URL(raw.startsWith("/spaces/") ? `/wiki${raw}` : raw, origin.origin);
    return url.origin === origin.origin ? url.href : undefined;
  } catch { return undefined; }
}

function nextCursor(raw: unknown): string | undefined {
  if (typeof raw !== "string" || raw.length > 8192) return undefined;
  try {
    const cursor = new URL(raw, "https://example.invalid").searchParams.get("cursor");
    return cursor && cursor.length <= 2048 && !/[\x00-\x1f\x7f]/.test(cursor) ? cursor : undefined;
  } catch { return undefined; }
}

export function formatResult(_config: Config, params: Params, data: any): object {
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Invalid Confluence response");
  const base = data._links?.base;
  if (params.operation === "list_spaces") {
    if (!Array.isArray(data.results)) throw new Error("Invalid Confluence spaces response");
    return {
      results: data.results.slice(0, 25).map((item: any) => ({
        id: typeof item?.id === "string" ? item.id.slice(0, 30) : undefined,
        key: typeof item?.key === "string" ? item.key.slice(0, 100) : undefined,
        name: typeof item?.name === "string" ? item.name.slice(0, 500) : undefined,
        type: typeof item?.type === "string" ? item.type.slice(0, 100) : undefined,
        status: typeof item?.status === "string" ? item.status.slice(0, 100) : undefined,
        url: pageLink(base, item?._links?.webui),
      })),
      nextCursor: nextCursor(data._links?.next),
    };
  }
  if (params.operation === "search") {
    if (!Array.isArray(data.results)) throw new Error("Invalid Confluence search response");
    return {
      results: data.results.slice(0, 25).map((item: any) => ({
        id: typeof item?.content?.id === "string" ? item.content.id.slice(0, 30) : undefined,
        title: typeof item?.title === "string" ? item.title.slice(0, 500) : undefined,
        excerpt: typeof item?.excerpt === "string" ? item.excerpt.slice(0, 2000) : undefined,
        space: typeof item?.content?.space?.key === "string" ? item.content.space.key.slice(0, 100) : undefined,
        lastModified: typeof item?.lastModified === "string" ? item.lastModified.slice(0, 100) : undefined,
        url: pageLink(base, item?.url ?? item?.content?._links?.webui),
      })),
      nextCursor: nextCursor(data._links?.next),
    };
  }
  const body = data.body?.storage?.value;
  if (typeof body !== "string") throw new Error("Confluence page has no storage body");
  return { id: typeof data.id === "string" ? data.id.slice(0, 30) : undefined,
    title: typeof data.title === "string" ? data.title.slice(0, 500) : undefined,
    lastModified: typeof data.version?.createdAt === "string" ? data.version.createdAt.slice(0, 100) : undefined,
    url: pageLink(base, data._links?.webui), body: body.slice(0, MAX_BODY), bodyFormat: "storage (HTML)", truncated: body.length > MAX_BODY };
}

export async function request(config: Config, params: Params, email: string | undefined, token: string | undefined, signal?: AbortSignal, fetcher: typeof fetch = fetch): Promise<object> {
  const url = buildRequest(config, params);
  if (!email || !token || /[\r\n:]/.test(email) || /[\r\n]/.test(token)) throw new Error("Set CONFLUENCE_EMAIL and CONFLUENCE_API_TOKEN before starting Pi");
  const controller = new AbortController();
  const abort = () => controller.abort();
  if (signal?.aborted) throw new Error("Confluence request cancelled");
  signal?.addEventListener("abort", abort, { once: true });
  const timer = setTimeout(abort, 30_000);
  try {
    const response = await fetcher(url, { method: "GET", redirect: "error", signal: controller.signal,
      headers: { Accept: "application/json", Authorization: `Basic ${Buffer.from(`${email}:${token}`).toString("base64")}` } });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`Confluence request failed (HTTP ${response.status})${response.status === 401 || response.status === 403 ? "; check token type, credentials, scopes and permissions" : ""}`);
    }
    if (!response.body) throw new Error("Empty Confluence response");
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > MAX_RESPONSE) { await reader.cancel(); throw new Error("Confluence response exceeds size limit"); }
        chunks.push(value);
      }
    } finally { reader.releaseLock(); }
    let data: unknown;
    try { data = JSON.parse(Buffer.concat(chunks).toString("utf8")); } catch { throw new Error("Invalid JSON response from Confluence"); }
    return formatResult(config, params, data);
  } catch (error) {
    if (controller.signal.aborted) throw new Error(signal?.aborted ? "Confluence request cancelled" : "Confluence request timed out");
    // Do not echo transport errors: they may contain credentials or URLs.
    if (error instanceof Error && /^(Confluence |Empty Confluence|Invalid JSON|Invalid Confluence)/.test(error.message)) throw error;
    throw new Error("Confluence request failed (network or redirect error)");
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", abort);
  }
}

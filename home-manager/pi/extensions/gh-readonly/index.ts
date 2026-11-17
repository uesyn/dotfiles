import { spawn } from "node:child_process";
import { isAbsolute } from "node:path";
import { ghExecutable } from "./endpoint.ts";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";

const schema = Type.Object({
  operation: Type.Union([
    Type.Literal("repo_view"),
    Type.Literal("pr_list"), Type.Literal("pr_view"),
    Type.Literal("issue_list"), Type.Literal("issue_view"),
  ]),
  repo: Type.String({ description: "Repository in owner/name form. Set GH_HOST before starting Pi for GitHub Enterprise." }),
  number: Type.Optional(Type.Integer({ minimum: 1, maximum: 2147483647 })),
  state: Type.Optional(Type.Union([Type.Literal("open"), Type.Literal("closed"), Type.Literal("all")])),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100 })),
}, { additionalProperties: false });
type Params = Static<typeof schema>;

export function buildArgs(p: Params, host: string): string[] {
  if (!/^[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?(?::[0-9]{1,5})?$/.test(host) || host.length > 253) throw new Error("Invalid GH_HOST");
  if (!/^[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+$/.test(p.repo) || p.repo.length > 200 || p.repo.split("/").some(s => s.startsWith("-") || s === "." || s === "..")) throw new Error("Invalid repository; expected owner/name");
  const allowed = new Map<string, readonly string[]>([
    ["repo_view", ["operation", "repo"]],
    ["pr_list", ["operation", "repo", "state", "limit"]],
    ["issue_list", ["operation", "repo", "state", "limit"]],
    ["pr_view", ["operation", "repo", "number"]],
    ["issue_view", ["operation", "repo", "number"]],
  ]);
  // A Map lookup, not an object index: a param named `constructor` or
  // `__proto__` must not resolve to an inherited value.
  const keys = allowed.get(p.operation);
  if (keys === undefined || Object.keys(p).some(k => !keys.includes(k))) throw new Error("Unsupported operation or parameter");
  const view = p.operation === "pr_view" || p.operation === "issue_view";
  if (view && (!Number.isInteger(p.number) || p.number! < 1 || p.number! > 2147483647)) throw new Error("A positive issue or PR number is required");
  if (p.limit !== undefined && (!Number.isInteger(p.limit) || p.limit < 1 || p.limit > 100)) throw new Error("Invalid limit");
  if (p.state !== undefined && !["open", "closed", "all"].includes(p.state)) throw new Error("Invalid state");
  const [kind, action] = p.operation.split("_");
  const args = [kind, action];
  if (view) args.push(String(p.number));
  if (kind === "repo") args.push(`${host}/${p.repo}`);
  else args.push("--repo", `${host}/${p.repo}`);
  if (action === "list") args.push("--limit", String(p.limit ?? 30), "--state", p.state ?? "open");
  const fields = kind === "repo" ? "nameWithOwner,description,url,defaultBranchRef,isPrivate" :
    kind === "pr" ? "number,title,state,url,author,body,createdAt,updatedAt,baseRefName,headRefName" :
    "number,title,state,url,author,body,createdAt,updatedAt";
  args.push("--json", fields);
  return args;
}

export function createGhReadonlyTool(executable = ghExecutable) {
  return defineTool({
    name: "gh", label: "GitHub (read-only)",
    description: "Read repository, pull request, and issue information using gh authentication. Set GH_HOST before starting Pi for GitHub Enterprise. No arbitrary commands or writes.",
    parameters: schema,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    async execute(_id, params, signal, _update, ctx) {
      const host = process.env.GH_HOST || "github.com";
      const args = buildArgs(params, host);
      if (signal?.aborted) throw new Error("gh request cancelled");
      if (!isAbsolute(executable)) throw new Error("gh executable path is not configured");
      const env = { ...process.env, GH_HOST: host, GH_PAGER: "cat", GH_PROMPT_DISABLED: "1", GH_NO_UPDATE_NOTIFIER: "1", NO_COLOR: "1" };
      delete env.GH_DEBUG;
      delete env.GH_REPO;
      delete env.DEBUG;
      return await new Promise((resolve) => {
        const child = spawn(executable, args, { cwd: ctx.cwd, env, shell: false, detached: true, stdio: ["ignore", "pipe", "pipe"] });
        const max = 128 * 1024;
        let output = Buffer.alloc(0), errors = Buffer.alloc(0), limited = false, timedOut = false, aborted = false, finished = false;
        let forceSettle: ReturnType<typeof setTimeout> | undefined;
        // Kill the whole process group: gh helpers that outlive the parent would
        // otherwise keep the stdio pipes open and `close` would never fire, so
        // the timeout would not actually bound the call. The fallback timer makes
        // settling unconditional even if a grandchild survives the kill.
        const stop = (reason: string) => {
          if (child.pid !== undefined && child.exitCode === null && child.signalCode === null) {
            try { process.kill(-child.pid, "SIGKILL"); }
            catch { try { child.kill("SIGKILL"); } catch { /* already gone */ } }
          }
          forceSettle ??= setTimeout(() => finish(null, reason), 1000);
        };
        const abort = () => { aborted = true; stop("Request cancelled"); };
        const timer = setTimeout(() => { timedOut = true; stop("Request timed out"); }, 30000);
        signal?.addEventListener("abort", abort, { once: true });
        if (signal?.aborted) abort();
        const collect = (current: Buffer, chunk: Buffer): Buffer => {
          if (current.length + chunk.length > max) { limited = true; stop("Output limit exceeded"); }
          return Buffer.concat([current, chunk.subarray(0, Math.max(0, max - current.length))]);
        };
        child.stdout.on("data", (chunk: Buffer) => { output = collect(output, chunk); });
        child.stderr.on("data", (chunk: Buffer) => { errors = collect(errors, chunk); });
        const finish = (code: number | null, error?: string) => {
          if (finished) return;
          finished = true; clearTimeout(timer); if (forceSettle !== undefined) clearTimeout(forceSettle); signal?.removeEventListener("abort", abort);
          const failed = code !== 0 || limited || timedOut || aborted || !!error;
          const message = [output.toString("utf8"), errors.toString("utf8"), error, limited ? "Output limit exceeded" : "", timedOut ? "Request timed out" : "", aborted ? "Request cancelled" : ""].filter(Boolean).join("\n");
          resolve({ content: [{ type: "text", text: message || (failed ? "gh failed" : "No results") }], details: { operation: params.operation, hostname: host, exitCode: code, truncated: limited }, isError: failed });
        };
        child.on("error", e => finish(null, `Failed to start gh: ${e.message}`));
        child.on("close", code => finish(code));
      });
    },
  });
}

export default function (pi: ExtensionAPI): void {
  pi.registerTool(createGhReadonlyTool());
}

import { isAbsolute } from "node:path";
import { capture, type CaptureResult } from "../lib/capture.ts";
import { ghExecutable } from "./endpoint.ts";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";

const repoSchema = () => Type.String({ description: "Repository in owner/name form. Set GH_HOST before starting Pi for GitHub Enterprise." });
const numberSchema = () => Type.Integer({ minimum: 1, maximum: 2147483647, description: "Issue or pull request number; required for view operations only." });
const stateSchema = () => Type.Optional(Type.Union([Type.Literal("open"), Type.Literal("closed"), Type.Literal("all")]));
const limitSchema = () => Type.Optional(Type.Integer({ minimum: 1, maximum: 100, description: "Maximum number of results; list operations only." }));

// Keep one tool, but give each operation its own exact input shape. A shared
// object with every optional field encourages models to send view-only fields
// with list operations (and vice versa), even when runtime validation rejects
// them correctly.
export const schema = Type.Union([
  Type.Object({
    operation: Type.Literal("repo_view"),
    repo: repoSchema(),
  }, { additionalProperties: false }),
  Type.Object({
    operation: Type.Literal("pr_list"),
    repo: repoSchema(),
    state: stateSchema(),
    limit: limitSchema(),
  }, { additionalProperties: false }),
  Type.Object({
    operation: Type.Literal("pr_view"),
    repo: repoSchema(),
    number: numberSchema(),
  }, { additionalProperties: false }),
  Type.Object({
    operation: Type.Literal("issue_list"),
    repo: repoSchema(),
    state: stateSchema(),
    limit: limitSchema(),
  }, { additionalProperties: false }),
  Type.Object({
    operation: Type.Literal("issue_view"),
    repo: repoSchema(),
    number: numberSchema(),
  }, { additionalProperties: false }),
]);
type Params = Static<typeof schema>;

const TIMEOUT_MS = 30_000;
// A result this large is a failure, not something to page through.
const OUTPUT_LIMIT_BYTES = 128 * 1024;
const TEMP_PREFIX = "pi-gh-";

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
  if (view && (!Number.isInteger(p.number) || p.number < 1 || p.number > 2147483647)) throw new Error("A positive issue or PR number is required");
  if ((p.operation === "pr_list" || p.operation === "issue_list") &&
      p.limit !== undefined && (!Number.isInteger(p.limit) || p.limit < 1 || p.limit > 100)) throw new Error("Invalid limit");
  if ((p.operation === "pr_list" || p.operation === "issue_list") &&
      p.state !== undefined && !["open", "closed", "all"].includes(p.state)) throw new Error("Invalid state");
  const [kind, action] = p.operation.split("_");
  const args = [kind, action];
  if (p.operation === "pr_view" || p.operation === "issue_view") args.push(String(p.number));
  if (kind === "repo") args.push(`${host}/${p.repo}`);
  else args.push("--repo", `${host}/${p.repo}`);
  if (p.operation === "pr_list" || p.operation === "issue_list") args.push("--limit", String(p.limit ?? 30), "--state", p.state ?? "open");
  const fields = kind === "repo" ? "nameWithOwner,description,url,defaultBranchRef,isPrivate" :
    kind === "pr" ? "number,title,state,url,author,body,createdAt,updatedAt,baseRefName,headRefName" :
    "number,title,state,url,author,body,createdAt,updatedAt";
  args.push("--json", fields);
  return args;
}

export function createGhReadonlyTool(executable = ghExecutable) {
  return defineTool({
    name: "gh", label: "GitHub (read-only)",
    description: "Read repository, pull request, and issue information using gh authentication. Each operation has an exact parameter shape: list takes repo/state/limit; view takes repo/number. Set GH_HOST before starting Pi for GitHub Enterprise. No arbitrary commands or writes.",
    parameters: schema,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    async execute(_id, params, signal, _update, ctx) {
      const host = process.env.GH_HOST || "github.com";
      const args = buildArgs(params, host);
      if (signal?.aborted) throw new Error("gh request cancelled");
      if (!isAbsolute(executable)) throw new Error("gh executable path is not configured");
      // gh honours its own debug and repository overrides; drop them so the
      // pinned arguments decide what runs and where.
      const env: NodeJS.ProcessEnv = { ...process.env, GH_HOST: host, GH_PAGER: "cat", GH_PROMPT_DISABLED: "1", GH_NO_UPDATE_NOTIFIER: "1", NO_COLOR: "1" };
      delete env.GH_DEBUG;
      delete env.GH_REPO;
      delete env.DEBUG;
      let run: CaptureResult;
      try {
        run = await capture({
          executable,
          argv: args,
          cwd: ctx.cwd,
          env,
          timeoutMs: TIMEOUT_MS,
          tempPrefix: TEMP_PREFIX,
          stdoutLimitBytes: OUTPUT_LIMIT_BYTES,
          // gh spawns helpers; a surviving one must not keep the call open.
          killProcessGroup: true,
          signal,
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text", text: `Failed to start gh: ${message}` }],
          details: {
            operation: params.operation,
            hostname: host,
            exitCode: null,
            truncated: false,
          },
          isError: true,
        };
      }
      const limited = run.stdoutLimitExceeded;
      const failed = run.exitCode !== 0 || limited || run.timedOut || run.aborted;
      const text = [
        run.stdoutHead,
        run.stderr,
        limited ? "Output limit exceeded" : "",
        run.timedOut ? "Request timed out" : "",
        run.aborted ? "Request cancelled" : "",
      ]
        .filter(Boolean)
        .join("\n");
      return {
        content: [{ type: "text", text: text || (failed ? "gh failed" : "No results") }],
        details: {
          operation: params.operation,
          hostname: host,
          exitCode: run.exitCode,
          truncated: limited || run.stderrTruncated,
        },
        isError: failed,
      };
    },
  });
}

export default function (pi: ExtensionAPI): void {
  pi.registerTool(createGhReadonlyTool());
}

/**
 * Read-only Git inspection tool.
 *
 * Safety notes:
 * - Every Git argument is passed as a single argv element to `spawn`; no shell
 *   is involved, so paths and revisions cannot escape into another command.
 * - Revisions are validated and never allowed to start with `-`. Paths are
 *   always placed after `--`; absolute paths, `..` traversal, and pathspec
 *   magic are rejected.
 * - The command allowlist below is the only way to run Git. There is no
 *   passthrough flag or raw-argument option.
 * - The Nix-managed Git executable is pinned at build time, not found via PATH.
 *   Pi runs outside nono; the command allowlist is not a sandbox.
 * - Optional locks are disabled so status/diff do not update `.git/index`.
 */

import { spawn } from "node:child_process";
import {
  appendFileSync,
  chmodSync,
  closeSync,
  mkdtempSync,
  openSync,
  rmSync,
  writeFileSync,
  writeSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join } from "node:path";
import { gitExecutable } from "./endpoint.ts";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  defineTool,
  truncateHead,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";

const TIMEOUT_MS = 30_000;
const HEAD_CAPTURE_BYTES = 256 * 1024;
const STDERR_CAPTURE_BYTES = 64 * 1024;
const MAX_PATHS = 100;
const MAX_TEXT_LENGTH = 4096;

const GLOBAL_OPTIONS = [
  "--no-pager",
  "--no-optional-locks",
  "-c",
  "color.ui=false",
  "-c",
  "core.fsmonitor=false",
  "-c",
  "log.showSignature=false",
  "-c",
  "core.quotePath=false",
] as const;

const pathsSchema = () =>
  Type.Optional(
    Type.Array(Type.String({ maxLength: MAX_TEXT_LENGTH }), {
      maxItems: MAX_PATHS,
      description:
        "Repository-relative paths. Passed after `--`; absolute paths, `..`, and pathspec magic are rejected.",
    }),
  );
const revisionSchema = (description: string) =>
  Type.Optional(Type.String({ maxLength: MAX_TEXT_LENGTH, description }));
const modeSchema = () =>
  Type.Optional(
    Type.Union(
      [
        Type.Literal("unstaged"),
        Type.Literal("staged"),
        Type.Literal("commit"),
        Type.Literal("range"),
      ],
      {
        description:
          "Diff mode: unstaged (default), staged, commit (requires rev), range (requires base; head defaults to HEAD).",
      },
    ),
  );
const rangeModeSchema = () =>
  Type.Optional(
    Type.Union([Type.Literal("three-dot"), Type.Literal("two-dot")], {
      description: "Separator for diff mode=range: three-dot (default) or two-dot.",
    }),
  );
const contextSchema = () =>
  Type.Optional(
    Type.Integer({
      minimum: 0,
      maximum: 50,
      description: "Patch context lines (default 3). Only available for patch output.",
    }),
  );
const diffFields = () => ({
  mode: modeSchema(),
  paths: pathsSchema(),
  rev: revisionSchema("Revision for diff mode=commit. Must not start with '-'."),
  base: revisionSchema("Base revision for diff mode=range."),
  head: revisionSchema("Head revision for diff mode=range (default HEAD)."),
  range_mode: rangeModeSchema(),
});

// Like gh, expose an exact shape for each operation instead of one object
// containing every operation's parameters.
export const GitParamsSchema = Type.Union([
  Type.Object(
    {
      operation: Type.Literal("status"),
      format: Type.Optional(
        Type.Union([Type.Literal("short"), Type.Literal("porcelain_v2")]),
      ),
      paths: pathsSchema(),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      operation: Type.Literal("diff"),
      ...diffFields(),
      format: Type.Optional(
        Type.Union([
          Type.Literal("patch"),
          Type.Literal("stat"),
          Type.Literal("name-only"),
          Type.Literal("name-status"),
        ]),
      ),
      context: contextSchema(),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      operation: Type.Literal("log"),
      rev: revisionSchema("Revision or range, e.g. HEAD~3 or main..feature."),
      paths: pathsSchema(),
      max_count: Type.Optional(
        Type.Integer({ minimum: 1, maximum: 200, description: "Maximum commits (default 20)." }),
      ),
      oneline: Type.Optional(Type.Boolean({ description: "Use one-line format (default true)." })),
      stat: Type.Optional(Type.Boolean({ description: "Include a diffstat." })),
      author: Type.Optional(Type.String({ maxLength: MAX_TEXT_LENGTH, description: "Filter by author." })),
      since: Type.Optional(Type.String({ maxLength: MAX_TEXT_LENGTH, description: "Filter by start date." })),
      until: Type.Optional(Type.String({ maxLength: MAX_TEXT_LENGTH, description: "Filter by end date." })),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      operation: Type.Literal("show"),
      rev: revisionSchema("Revision to show (default HEAD)."),
      paths: pathsSchema(),
      format: Type.Optional(
        Type.Union([
          Type.Literal("patch"),
          Type.Literal("stat"),
          Type.Literal("name-only"),
          Type.Literal("name-status"),
        ]),
      ),
      context: contextSchema(),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      operation: Type.Literal("branch"),
      all: Type.Optional(Type.Boolean({ description: "Include remote-tracking branches." })),
      verbose: Type.Optional(Type.Boolean({ description: "Show upstream information." })),
      contains: revisionSchema("Only list branches containing this revision."),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      operation: Type.Literal("blame"),
      paths: Type.Array(Type.String({ maxLength: MAX_TEXT_LENGTH }), {
        minItems: 1,
        maxItems: 1,
        description: "Exactly one repository-relative path to blame.",
      }),
      rev: revisionSchema("Revision to blame (default working tree)."),
      line_start: Type.Optional(Type.Integer({ minimum: 1, description: "First line (1-based)." })),
      line_end: Type.Optional(Type.Integer({ minimum: 1, description: "Last line (inclusive)." })),
    },
    { additionalProperties: false },
  ),
  Type.Object(
    {
      operation: Type.Literal("rev_parse"),
      what: Type.Optional(
        Type.Union([
          Type.Literal("rev"),
          Type.Literal("toplevel"),
          Type.Literal("is-inside-work-tree"),
          Type.Literal("short-sha"),
        ]),
      ),
      rev: revisionSchema("Revision to resolve (default HEAD)."),
    },
    { additionalProperties: false },
  ),
]);

type GitParams = Static<typeof GitParamsSchema>;
type Operation = GitParams["operation"];
type ParameterKey =
  | "paths"
  | "rev"
  | "base"
  | "head"
  | "mode"
  | "format"
  | "context"
  | "max_count"
  | "oneline"
  | "stat"
  | "author"
  | "since"
  | "until"
  | "all"
  | "verbose"
  | "contains"
  | "line_start"
  | "line_end"
  | "range_mode"
  | "what";
type NormalizedGitParams = {
  operation: Operation;
  paths?: string[];
  rev?: string;
  base?: string;
  head?: string;
  mode?: "unstaged" | "staged" | "commit" | "range";
  format?: string;
  context?: number;
  max_count?: number;
  oneline?: boolean;
  stat?: boolean;
  author?: string;
  since?: string;
  until?: string;
  all?: boolean;
  verbose?: boolean;
  contains?: string;
  line_start?: number;
  line_end?: number;
  range_mode?: "three-dot" | "two-dot";
  what?: "rev" | "toplevel" | "is-inside-work-tree" | "short-sha";
};
type DiffFormat = "patch" | "stat" | "name-only" | "name-status";

const GitOutputSchema = Type.Object(
  {
    operation: Type.String(),
    argv: Type.Array(Type.String()),
    content: Type.String(),
    exitCode: Type.Union([Type.Number(), Type.Null()]),
    signal: Type.Union([Type.String(), Type.Null()]),
    timedOut: Type.Boolean(),
    aborted: Type.Boolean(),
    stdoutBytes: Type.Number(),
    stderrBytes: Type.Number(),
    stderrTruncated: Type.Boolean(),
    truncated: Type.Boolean(),
    fullOutputPath: Type.Optional(Type.String()),
  },
  { additionalProperties: false },
);

type GitOutput = Static<typeof GitOutputSchema>;

const OPERATION_PARAMETER_KEYS: Record<Operation, readonly ParameterKey[]> = {
  status: ["format", "paths"],
  diff: ["mode", "format", "context", "paths", "rev", "base", "head", "range_mode"],
  log: ["rev", "paths", "max_count", "oneline", "stat", "author", "since", "until"],
  show: ["rev", "format", "context", "paths"],
  branch: ["all", "verbose", "contains"],
  blame: ["paths", "rev", "line_start", "line_end"],
  rev_parse: ["rev", "what"],
};

const KNOWN_PARAMETER_KEYS = new Set<string>(Object.values(OPERATION_PARAMETER_KEYS).flat());
const STATUS_FORMATS = new Set(["short", "porcelain_v2"]);
const DIFF_FORMATS = new Set<DiffFormat>(["patch", "stat", "name-only", "name-status"]);

const REV_PATTERN = /^[A-Za-z0-9_./@{}^~+!-]+$/;

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function normalizeParams(params: GitParams): NormalizedGitParams {
  const operation = params.operation;
  if (!Object.hasOwn(OPERATION_PARAMETER_KEYS, operation)) {
    throw new Error(`unsupported operation: ${String(operation)}`);
  }

  const supported = new Set(OPERATION_PARAMETER_KEYS[operation]);
  const normalized: Record<string, unknown> = { operation };
  for (const [key, value] of Object.entries(params)) {
    if (key === "operation") continue;
    if (!KNOWN_PARAMETER_KEYS.has(key)) {
      throw new Error(`Parameter "${key}" is not supported for operation "${operation}"`);
    }
    // Model-facing schemas sometimes fill fields belonging to other operations.
    // Ignore those fields and treat empty strings as omitted. Keep parameters
    // belonging to this operation so its existing semantic validation runs.
    if (!supported.has(key) || value === "") continue;
    normalized[key] = value;
  }
  return normalized as NormalizedGitParams;
}

function validateOptionValue(value: string, name: string): string {
  if (typeof value !== "string") {
    throw new Error(`"${name}" must be a string`);
  }
  if (value.trim().length === 0) {
    throw new Error(`"${name}" must not be empty`);
  }
  if (value.length > MAX_TEXT_LENGTH) {
    throw new Error(`"${name}" is too long (maximum ${MAX_TEXT_LENGTH} characters)`);
  }
  if (/[\x00-\x1f\x7f]/.test(value)) {
    throw new Error(`"${name}" must not contain control characters`);
  }
  return value;
}

function validateRevision(value: string, name: string): string {
  const revision = validateOptionValue(value, name);
  if (revision.startsWith("-")) {
    throw new Error(`"${name}" must not start with '-'`);
  }
  if (!REV_PATTERN.test(revision)) {
    throw new Error(`"${name}" contains unsupported revision characters`);
  }
  return revision;
}

function validatePath(value: string): string {
  if (typeof value !== "string") {
    throw new Error("paths must be strings");
  }
  if (value.length === 0) {
    throw new Error("paths must not contain an empty string");
  }
  if (value.length > MAX_TEXT_LENGTH) {
    throw new Error(`path is too long (maximum ${MAX_TEXT_LENGTH} characters)`);
  }
  if (/[\x00-\x1f\x7f]/.test(value)) {
    throw new Error("paths must not contain control characters");
  }
  if (value.startsWith("/") || value.startsWith("\\") || /^[A-Za-z]:/.test(value)) {
    throw new Error(`absolute paths are not allowed: ${value}`);
  }
  // Reject pathspec magic. It is not needed for read-only inspection and
  // keeps the accepted path grammar small.
  if (value.startsWith(":")) {
    throw new Error(`pathspec magic is not allowed: ${value}`);
  }
  if (value.split(/[\\/]+/).includes("..")) {
    throw new Error(`paths must not contain '..': ${value}`);
  }
  return value;
}

function requireValue(value: string | undefined, name: string): string {
  if (value === undefined) {
    throw new Error(`"${name}" is required for this operation`);
  }
  return value;
}

function pushDiffFormat(args: string[], format: DiffFormat): void {
  if (format === "stat") args.push("--stat");
  else if (format === "name-only") args.push("--name-only");
  else if (format === "name-status") args.push("--name-status");
}

function resolveDiffContext(params: NormalizedGitParams, format: DiffFormat): number {
  // Treat context as inapplicable for summary formats. Keeping this tolerant
  // at runtime also handles older callers that sent schema-generated 0 values.
  if (format !== "patch") return 3;
  const context = params.context ?? 3;
  if (!Number.isInteger(context) || context < 0 || context > 50) {
    throw new Error('"context" must be an integer between 0 and 50');
  }
  return context;
}

function buildDiffArgs(
  params: NormalizedGitParams,
  paths: string[],
  mode: "unstaged" | "staged" | "commit" | "range",
): string[] {
  if (mode !== "unstaged" && mode !== "staged" && mode !== "commit" && mode !== "range") {
    throw new Error(`unsupported diff mode: ${String(mode)}`);
  }
  const format = (params.format ?? "patch") as DiffFormat;
  if (!DIFF_FORMATS.has(format)) {
    throw new Error(`format "${format}" is not supported for operation "diff"`);
  }

  if (mode === "commit") {
    if (params.base !== undefined || params.head !== undefined || params.range_mode !== undefined) {
      throw new Error('"base", "head", and "range_mode" are only supported with mode "range"');
    }
    const rev = validateRevision(requireValue(params.rev, "rev"), "rev");
    const context = resolveDiffContext(params, format);
    const args = [
      ...GLOBAL_OPTIONS,
      "show",
      "--no-ext-diff",
      "--no-textconv",
      "--no-show-signature",
      "--ignore-submodules=all",
      "--format=",
    ];
    pushDiffFormat(args, format);
    if (format === "patch") args.push(`-U${context}`);
    args.push("--end-of-options", rev);
    if (paths.length > 0) args.push("--", ...paths);
    return args;
  }

  if (mode === "range") {
    if (params.rev !== undefined) {
      throw new Error('"rev" is only supported with mode "commit"');
    }
    const base = validateRevision(requireValue(params.base, "base"), "base");
    const head = validateRevision(params.head ?? "HEAD", "head");
    const rangeMode = params.range_mode ?? "three-dot";
    if (rangeMode !== "two-dot" && rangeMode !== "three-dot") {
      throw new Error(`unsupported range_mode: ${String(rangeMode)}`);
    }
    const separator = rangeMode === "two-dot" ? ".." : "...";
    const context = resolveDiffContext(params, format);
    const args = [
      ...GLOBAL_OPTIONS,
      "diff",
      "--no-ext-diff",
      "--no-textconv",
      "--ignore-submodules=all",
    ];
    pushDiffFormat(args, format);
    if (format === "patch") args.push(`-U${context}`);
    args.push("--end-of-options", `${base}${separator}${head}`);
    if (paths.length > 0) args.push("--", ...paths);
    return args;
  }

  if (params.rev !== undefined || params.base !== undefined || params.head !== undefined || params.range_mode !== undefined) {
    throw new Error('"rev", "base", "head", and "range_mode" are not supported for this diff mode');
  }

  const context = resolveDiffContext(params, format);
  const args = [
    ...GLOBAL_OPTIONS,
    "diff",
    "--no-ext-diff",
    "--no-textconv",
    "--ignore-submodules=all",
  ];
  if (mode === "staged") args.push("--cached");
  pushDiffFormat(args, format);
  if (format === "patch") args.push(`-U${context}`);
  if (paths.length > 0) args.push("--", ...paths);
  return args;
}

function buildGitArgs(rawParams: GitParams): string[] {
  const params = normalizeParams(rawParams);

  if (params.paths !== undefined && !Array.isArray(params.paths)) {
    throw new Error('"paths" must be an array of strings');
  }
  const paths = (params.paths ?? []).map(validatePath);

  switch (params.operation) {
    case "status": {
      const format = params.format ?? "short";
      if (!STATUS_FORMATS.has(format)) {
        throw new Error(`format "${format}" is not supported for operation "status"`);
      }
      const args = [...GLOBAL_OPTIONS, "status"];
      if (format === "porcelain_v2") args.push("--porcelain=v2", "--branch");
      else args.push("--short", "--branch");
      args.push("--untracked-files=normal", "--ignore-submodules=all");
      if (paths.length > 0) args.push("--", ...paths);
      return args;
    }

    case "diff": {
      const mode = params.mode ?? "unstaged";
      return buildDiffArgs(params, paths, mode);
    }

    case "log": {
      const maxCount = params.max_count ?? 20;
      if (!Number.isInteger(maxCount) || maxCount < 1 || maxCount > 200) {
        throw new Error('"max_count" must be an integer between 1 and 200');
      }
      const oneline = params.oneline ?? true;
      const args = [
        ...GLOBAL_OPTIONS,
        "log",
        "--no-ext-diff",
        "--no-textconv",
        "--no-show-signature",
        "--decorate=short",
        `--max-count=${maxCount}`,
      ];
      if (oneline) args.push("--oneline");
      if (params.stat === true) args.push("--stat");
      if (params.author !== undefined) {
        args.push(`--author=${validateOptionValue(params.author, "author")}`);
      }
      if (params.since !== undefined) {
        args.push(`--since=${validateOptionValue(params.since, "since")}`);
      }
      if (params.until !== undefined) {
        args.push(`--until=${validateOptionValue(params.until, "until")}`);
      }
      if (params.rev !== undefined) {
        args.push("--end-of-options", validateRevision(params.rev, "rev"));
      }
      if (paths.length > 0) args.push("--", ...paths);
      return args;
    }

    case "show": {
      const format = (params.format ?? "patch") as DiffFormat;
      if (!DIFF_FORMATS.has(format)) {
        throw new Error(`format "${format}" is not supported for operation "show"`);
      }
      const rev = validateRevision(params.rev ?? "HEAD", "rev");
      const context = resolveDiffContext(params, format);
      const args = [
        ...GLOBAL_OPTIONS,
        "show",
        "--no-ext-diff",
        "--no-textconv",
        "--no-show-signature",
        "--ignore-submodules=all",
      ];
      pushDiffFormat(args, format);
      if (format === "patch") args.push(`-U${context}`);
      args.push("--end-of-options", rev);
      if (paths.length > 0) args.push("--", ...paths);
      return args;
    }

    case "branch": {
      const args = [...GLOBAL_OPTIONS, "branch", "--list", "--no-column"];
      if (params.all === true) args.push("--all");
      if (params.verbose === true) args.push("--verbose");
      if (params.contains !== undefined) {
        args.push(`--contains=${validateRevision(params.contains, "contains")}`);
      }
      return args;
    }

    case "blame": {
      if (paths.length !== 1) {
        throw new Error('operation "blame" requires exactly one path');
      }
      const args = [
        ...GLOBAL_OPTIONS,
        "blame",
        "--no-textconv",
        "--no-ext-diff",
        "--no-show-signature",
        "--date=short",
      ];
      if (params.line_start !== undefined || params.line_end !== undefined) {
        if (params.line_start === undefined || params.line_end === undefined) {
          throw new Error('"line_start" and "line_end" must be specified together');
        }
        if (
          !Number.isInteger(params.line_start) ||
          !Number.isInteger(params.line_end) ||
          params.line_start < 1 ||
          params.line_end < 1
        ) {
          throw new Error('"line_start" and "line_end" must be positive integers');
        }
        if (params.line_end < params.line_start) {
          throw new Error('"line_end" must be greater than or equal to "line_start"');
        }
        args.push(`-L${params.line_start},${params.line_end}`);
      }
      if (params.rev !== undefined) {
        args.push(validateRevision(params.rev, "rev"));
      }
      args.push("--", paths[0]);
      return args;
    }

    case "rev_parse": {
      const what = params.what ?? "rev";
      if (what === "toplevel" || what === "is-inside-work-tree") {
        if (params.rev !== undefined) {
          throw new Error(`"rev" is not supported when what is "${what}"`);
        }
        return [
          ...GLOBAL_OPTIONS,
          "rev-parse",
          what === "toplevel" ? "--show-toplevel" : "--is-inside-work-tree",
        ];
      }
      if (what === "rev" || what === "short-sha") {
        const rev = validateRevision(params.rev ?? "HEAD", "rev");
        const args = [...GLOBAL_OPTIONS, "rev-parse", "--verify"];
        if (what === "short-sha") args.push("--short");
        args.push("--end-of-options", rev);
        return args;
      }
      throw new Error(`unsupported rev_parse target: ${String(what)}`);
    }

    default:
      throw new Error(`unsupported operation: ${String(params.operation)}`);
  }
}

function buildEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    // Drop every inherited Git override: GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE,
    // GIT_CONFIG*, GIT_SSH*, GIT_EXTERNAL_DIFF, GIT_PAGER, GIT_ASKPASS, ...
    // The tool supplies the only Git environment it needs below.
    if (key.startsWith("GIT_")) continue;
    if (key === "SSH_ASKPASS" || key === "SSH_AUTH_SOCK") continue;
    env[key] = value;
  }
  env.GIT_PAGER = "cat";
  env.GIT_OPTIONAL_LOCKS = "0";
  env.GIT_TERMINAL_PROMPT = "0";
  env.GIT_EXTERNAL_DIFF = "";
  return env;
}

interface RunResult {
  stdoutHead: string;
  stdoutBytes: number;
  stderr: string;
  stderrBytes: number;
  stderrTruncated: boolean;
  exitCode: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
  aborted: boolean;
  fullStdoutPath?: string;
}

function runGit(
  executable: string,
  args: string[],
  cwd: string,
  signal: AbortSignal | undefined,
): Promise<RunResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      cwd,
      env: buildEnv(),
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
    });

    const headChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    let headBytes = 0;
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let stderrCaptured = 0;
    let stderrTruncated = false;
    let tempPath: string | undefined;
    let tempFd: number | undefined;
    let timedOut = false;
    let aborted = false;
    let settled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;

    function removeTemp(): void {
      if (tempPath === undefined) return;
      try {
        rmSync(dirname(tempPath), { recursive: true, force: true });
      } catch {
        // Best-effort cleanup only.
      }
      tempPath = undefined;
    }

    function cleanup(): void {
      if (timer !== undefined) clearTimeout(timer);
      if (signal !== undefined) signal.removeEventListener("abort", onAbort);
      if (tempFd !== undefined) {
        try {
          closeSync(tempFd);
        } catch {
          // The stream may already be closed.
        }
        tempFd = undefined;
      }
    }

    function ensureTemp(): void {
      if (tempPath !== undefined) return;
      const dir = mkdtempSync(join(tmpdir(), "pi-git-"));
      chmodSync(dir, 0o700);
      tempPath = join(dir, "output.txt");
      tempFd = openSync(tempPath, "w", 0o600);
    }

    function finish(code: number | null, childSignal: NodeJS.Signals | null): void {
      if (settled) return;
      settled = true;
      cleanup();
      resolve({
        stdoutHead: Buffer.concat(headChunks).toString("utf8"),
        stdoutBytes,
        stderr: Buffer.concat(stderrChunks).toString("utf8"),
        stderrBytes,
        stderrTruncated,
        exitCode: code,
        signal: childSignal,
        timedOut,
        aborted,
        fullStdoutPath: tempPath,
      });
    }

    function fail(error: unknown): void {
      if (settled) return;
      settled = true;
      cleanup();
      removeTemp();
      reject(error instanceof Error ? error : new Error(String(error)));
    }

    function onStdout(chunk: Buffer): void {
      try {
        stdoutBytes += chunk.length;
        if (tempFd !== undefined) {
          writeSync(tempFd, chunk);
          return;
        }
        const remaining = HEAD_CAPTURE_BYTES - headBytes;
        if (chunk.length <= remaining) {
          headChunks.push(chunk);
          headBytes += chunk.length;
          return;
        }
        ensureTemp();
        const fd = tempFd;
        if (fd === undefined) throw new Error("failed to create temporary output file");
        for (const buffered of headChunks) writeSync(fd, buffered);
        writeSync(fd, chunk);
        if (remaining > 0) {
          headChunks.push(chunk.subarray(0, remaining));
          headBytes += remaining;
        }
      } catch (error) {
        child.kill("SIGKILL");
        fail(error);
      }
    }

    function onStderr(chunk: Buffer): void {
      try {
        stderrBytes += chunk.length;
        if (stderrCaptured >= STDERR_CAPTURE_BYTES) {
          stderrTruncated = true;
          return;
        }
        const remaining = STDERR_CAPTURE_BYTES - stderrCaptured;
        const taken = chunk.length <= remaining ? chunk : chunk.subarray(0, remaining);
        stderrChunks.push(taken);
        stderrCaptured += taken.length;
        if (taken.length < chunk.length) stderrTruncated = true;
      } catch (error) {
        child.kill("SIGKILL");
        fail(error);
      }
    }

    function onAbort(): void {
      if (settled) return;
      aborted = true;
      child.kill("SIGKILL");
    }

    child.stdout.on("data", onStdout);
    child.stderr.on("data", onStderr);
    child.on("error", fail);
    child.on("close", finish);

    timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, TIMEOUT_MS);

    if (signal !== undefined) {
      if (signal.aborted) onAbort();
      else signal.addEventListener("abort", onAbort, { once: true });
    }
  });
}

function writeTempOutput(text: string): string {
  const dir = mkdtempSync(join(tmpdir(), "pi-git-"));
  chmodSync(dir, 0o700);
  const path = join(dir, "output.txt");
  writeFileSync(path, text, { mode: 0o600 });
  return path;
}

function appendStderrToOutput(path: string, stderr: string, truncated: boolean): void {
  if (stderr.length === 0) return;
  const suffix = `\n\n[stderr]\n${stderr}${truncated ? "\n[stderr truncated]" : ""}\n`;
  appendFileSync(path, suffix, { mode: 0o600 });
}

function buildSuccessContent(run: RunResult): string {
  const sections: string[] = [];
  const stdout = run.stdoutHead.trimEnd();
  const stderr = run.stderr.trimEnd();
  if (stdout.length > 0) sections.push(stdout);
  if (stderr.length > 0) sections.push(`[stderr]\n${stderr}`);
  if (run.stderrTruncated) sections.push("[stderr truncated]");
  return sections.length > 0 ? sections.join("\n\n") : "(no output)";
}

function buildFailureContent(operation: Operation, run: RunResult): string {
  const header = run.timedOut
    ? `git ${operation} timed out after ${TIMEOUT_MS / 1000}s`
    : run.aborted
      ? `git ${operation} was cancelled`
      : `git ${operation} failed (${
          run.exitCode !== null ? `exit ${run.exitCode}` : `signal ${run.signal ?? "unknown"}`
        })`;
  const sections: string[] = [header];
  const stderr = run.stderr.trimEnd();
  const stdout = run.stdoutHead.trimEnd();
  if (stderr.length > 0) sections.push(stderr);
  if (stdout.length > 0) sections.push(stdout);
  if (run.stderrTruncated) sections.push("[stderr truncated]");
  return sections.join("\n\n");
}

function errorResult(
  operation: Operation,
  argv: string[],
  message: string,
  aborted = false,
): { content: [{ type: "text"; text: string }]; details: GitOutput; structuredContent: GitOutput; isError: true } {
  const details: GitOutput = {
    operation,
    argv,
    content: message,
    exitCode: null,
    signal: null,
    timedOut: false,
    aborted,
    stdoutBytes: 0,
    stderrBytes: 0,
    stderrTruncated: false,
    truncated: false,
  };
  return {
    content: [{ type: "text", text: message }],
    details,
    structuredContent: details,
    isError: true,
  };
}

// SDK subagents reuse the same validation and pinned executable.
export function createGitReadonlyTool(executable = gitExecutable) {
  return defineTool<typeof GitParamsSchema, GitOutput>({
    name: "git",
    label: "Git (read-only)",
    description:
      "Inspect a Git repository without modifying it. Each operation exposes only its relevant parameters. Supports status, diff, log, show, branch, blame, and rev-parse; no network access or mutating commands.",
    promptSnippet:
      "Read-only Git inspection (status, diff, log, show, branch, blame, rev-parse).",
    promptGuidelines: [
      "Use the `git` tool instead of `bash git ...` to inspect repository state; it is read-only and cannot commit, checkout, fetch, or push.",
      "Choose the schema variant for the selected operation; omit optional parameters to use their defaults.",
    ],
    parameters: GitParamsSchema,
    outputSchema: GitOutputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      let argv: string[];
      try {
        argv = buildGitArgs(params);
      } catch (error) {
        throw new Error(`Invalid git tool arguments: ${errorMessage(error)}`);
      }

      if (signal?.aborted) {
        return errorResult(params.operation, argv, "git tool call was cancelled", true);
      }

      let run: RunResult;
      try {
        if (!isAbsolute(executable)) throw new Error("git executable path is not configured");
        run = await runGit(executable, argv, ctx.cwd, signal);
      } catch (error) {
        return errorResult(
          params.operation,
          argv,
          `Failed to run git: ${errorMessage(error)}`,
        );
      }

      const failed =
        run.exitCode !== 0 || run.timedOut || run.aborted || run.signal !== null;

      const rawContent = failed
        ? buildFailureContent(params.operation, run)
        : buildSuccessContent(run);
      const truncatedContent = truncateHead(rawContent, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      let fullOutputPath = run.fullStdoutPath;
      const truncated = truncatedContent.truncated;
      let content = truncatedContent.content;

      if (truncated) {
        if (fullOutputPath !== undefined) {
          appendStderrToOutput(fullOutputPath, run.stderr, run.stderrTruncated);
        } else {
          fullOutputPath = writeTempOutput(rawContent);
        }
        const fullSize = run.fullStdoutPath !== undefined
          ? `stdout ${formatSize(run.stdoutBytes)}`
          : `${truncatedContent.totalLines} lines, ${formatSize(truncatedContent.totalBytes)}`;
        content += `\n\n[Output truncated (${fullSize}). Full output: ${fullOutputPath}]`;
      } else if (fullOutputPath !== undefined) {
        // Keep the path available in structured details even if the head fits.
        content += `\n\n[Full output: ${fullOutputPath}]`;
      }

      const details: GitOutput = {
        operation: params.operation,
        argv,
        content,
        exitCode: run.exitCode,
        signal: run.signal,
        timedOut: run.timedOut,
        aborted: run.aborted,
        stdoutBytes: run.stdoutBytes,
        stderrBytes: run.stderrBytes,
        stderrTruncated: run.stderrTruncated,
        truncated,
        ...(fullOutputPath !== undefined ? { fullOutputPath } : {}),
      };

      return {
        content: [{ type: "text", text: content }],
        details,
        structuredContent: details,
        isError: failed,
      };
    },
  });
}

export default function gitReadonlyExtension(pi: ExtensionAPI): void {
  pi.registerTool(createGitReadonlyTool());
}

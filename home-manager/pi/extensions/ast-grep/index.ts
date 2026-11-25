/**
 * Structural code search with ast-grep.
 *
 * Safety notes:
 * - Every argument is passed as a single argv element to `spawn`; no shell is
 *   involved, so patterns, paths, globs and rules cannot escape into another
 *   command.
 * - No rewrite flag is ever emitted (`-r`, `--rewrite`, `-U`, `--update-all`,
 *   `-i`, `--interactive`). The tool cannot modify files; rewriting stays the
 *   job of the `write`/`edit` tools.
 * - Paths are validated like the `git` tool: repository-relative, no absolute
 *   paths, no `..` traversal, no control characters. Paths always follow `--`.
 * - The pattern is rejected when it starts with `-`, so it can never be read as
 *   a flag by ast-grep's argument parser.
 * - ast-grep is started through PATH so an outer nono profile (and its exec
 *   gate) applies. Do not replace this with a store absolute path.
 * - Ambient configuration is stripped from the environment (`AST_GREP_*` and
 *   the color variables), so results depend only on the project's own config.
 * - Project configuration is neutralised: every invocation passes `-c` with an
 *   empty config this extension creates in a private temporary directory, and
 *   `--custom-languages ignore`. ast-grep discovers `sgconfig.yml` by walking up
 *   from the working directory, so a repository (or any ancestor directory)
 *   could otherwise change language mappings or load a native custom-language
 *   library (`customLanguages` + `libraryPath`) that runs code with the user's
 *   permissions.
 * - Paths are not followed through symlinks: ast-grep only traverses symlinks
 *   with `--follow`, which this tool never passes. Naming a symlink directly in
 *   `paths` still reads its target, exactly like the `read` and `grep` tools.
 */

import { chmodSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { StringEnum } from "@earendil-works/pi-ai";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  defineTool,
  formatSize,
  truncateHead,
  truncateLine,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";
import {
  capture,
  appendStderrToOutput,
  writeTempOutput,
  type CaptureResult,
} from "../lib/capture.ts";

const TIMEOUT_MS = 30_000;
const TEMP_PREFIX = "pi-ast-grep-";
const MAX_TEXT_LENGTH = 4096;
const MAX_RULE_LENGTH = 16 * 1024;
const MAX_PATHS = 16;
const MAX_GLOBS = 16;
const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 500;
const MAX_MATCH_LINES = 20;

// An explicit, empty configuration. `ruleDirs: []` keeps ast-grep from needing
// to resolve rules, and pointing `-c` at it stops the implicit `sgconfig.yml`
// discovery that would otherwise walk up from the working directory.
const NEUTRAL_CONFIG = "ruleDirs: []\n";
let neutralConfigPath: string | undefined;

/**
 * Creates (once per process) the empty config passed as `-c`. Throws instead of
 * falling back to unconfigured discovery, so a failure fails closed.
 */
function getNeutralConfigPath(): string {
  if (neutralConfigPath !== undefined) return neutralConfigPath;
  const dir = mkdtempSync(join(tmpdir(), "pi-ast-grep-config-"));
  chmodSync(dir, 0o700);
  const path = join(dir, "sgconfig.yml");
  writeFileSync(path, NEUTRAL_CONFIG, { mode: 0o600 });
  neutralConfigPath = path;
  return path;
}

// Built-in ast-grep languages and their CLI aliases. Keeping this closed both
// fails fast on typos and shows the model which languages structural search
// supports (custom `languageGlobs` grammars need a shared library on disk and
// are out of scope).
const LANGUAGES = [
  "bash",
  "c",
  "cpp",
  "cs",
  "css",
  "ex",
  "go",
  "hs",
  "hcl",
  "html",
  "java",
  "js",
  "jsx",
  "json",
  "kt",
  "lua",
  "md",
  "nix",
  "php",
  "py",
  "rb",
  "rs",
  "scala",
  "sol",
  "swift",
  "ts",
  "tsx",
  "yml",
] as const;

const STRICTNESS = ["cst", "smart", "ast", "relaxed", "signature", "template"] as const;
const DEBUG_MODES = ["pattern", "ast", "cst", "sexp"] as const;

const LanguageSchema = StringEnum(LANGUAGES, {
  description: "Language of the pattern and the files to search.",
});
const StrictnessSchema = StringEnum(STRICTNESS, {
  description:
    "How strictly nodes must match (default smart). `relaxed`/`signature` ignore comments and text.",
});
const DebugModeSchema = StringEnum(DEBUG_MODES, {
  description: "Which representation of the parsed pattern to print (default ast).",
});
const OperationSchema = StringEnum(["search", "rule", "debug"] as const, {
  description:
    "Operation (default search). search: pattern or node kind. rule: inline ast-grep YAML rule. debug: print how a pattern parses.",
});
const FormatSchema = StringEnum(["text", "json"] as const, {
  description: "Result format (default text). json returns the same matches as structured data.",
});

const AstGrepParamsSchema = Type.Object(
  {
    operation: Type.Optional(OperationSchema),
    pattern: Type.Optional(
      Type.String({
        maxLength: MAX_TEXT_LENGTH,
        description:
          'ast-grep pattern for operation "search", e.g. "await fetch($URL)" or "class $NAME extends $BASE { $$$BODY }". Metavariables: $A single node, $$$ARGS many nodes. Must not start with \'-\'. May span lines.',
      }),
    ),
    kind: Type.Optional(
      Type.String({
        maxLength: MAX_TEXT_LENGTH,
        description:
          'Node kind or ESQuery-style selector for operation "search", e.g. "call_expression", "function_declaration[name=foo]", "call_expression > identifier". Use instead of pattern when matching by syntax kind.',
      }),
    ),
    rule: Type.Optional(
      Type.String({
        maxLength: MAX_RULE_LENGTH,
        description:
          'YAML rule for operation "rule", with required `id`, `language`, and `rule` fields. Needed for relational searches (inside/has/precedes/follows) that patterns cannot express.',
      }),
    ),
    lang: Type.Optional(LanguageSchema),
    strictness: Type.Optional(StrictnessSchema),
    selector: Type.Optional(
      Type.String({
        maxLength: MAX_TEXT_LENGTH,
        description:
          'Node kind to extract from the pattern as the actual matcher, e.g. "identifier" to match only $NAME. Requires "pattern".',
      }),
    ),
    debug: Type.Optional(DebugModeSchema),
    paths: Type.Optional(
      Type.Array(Type.String({ maxLength: MAX_TEXT_LENGTH }), {
        maxItems: MAX_PATHS,
        description:
          "Repository-relative paths (default current directory). Absolute paths, `..`, and leading ':' are rejected.",
      }),
    ),
    globs: Type.Optional(
      Type.Array(Type.String({ maxLength: MAX_TEXT_LENGTH }), {
        maxItems: MAX_GLOBS,
        description:
          "Include/exclude globs in .gitignore style, e.g. 'src/**/*.ts' or '!**/test/**'. A leading './' is stripped.",
      }),
    ),
    limit: Type.Optional(
      Type.Integer({
        minimum: 1,
        maximum: MAX_LIMIT,
        description: `Maximum matches to return (default ${DEFAULT_LIMIT}).`,
      }),
    ),
    format: Type.Optional(FormatSchema),
  },
  { additionalProperties: false },
);

type AstGrepParams = Static<typeof AstGrepParamsSchema>;
type Operation = Required<AstGrepParams>["operation"];

const AstGrepMatchSchema = Type.Object(
  {
    file: Type.String(),
    startLine: Type.Integer({ description: "1-based line." }),
    startColumn: Type.Integer({ description: "1-based column." }),
    endLine: Type.Integer(),
    endColumn: Type.Integer(),
    text: Type.String({ description: "Full text of the matched node." }),
    language: Type.Optional(Type.String()),
    ruleId: Type.Optional(Type.String()),
    severity: Type.Optional(Type.String()),
    message: Type.Optional(Type.String()),
    metaVariables: Type.Optional(
      Type.Record(Type.String(), Type.String(), {
        description: "Single metavariables captured by the pattern, e.g. { NAME: \"Foo\" }.",
      }),
    ),
  },
  { additionalProperties: false },
);

const AstGrepOutputSchema = Type.Object(
  {
    operation: Type.String(),
    argv: Type.Array(Type.String()),
    content: Type.String(),
    matchCount: Type.Integer(),
    fileCount: Type.Integer(),
    limitReached: Type.Boolean(),
    matches: Type.Array(AstGrepMatchSchema),
    exitCode: Type.Union([Type.Number(), Type.Null()]),
    signal: Type.Union([Type.String(), Type.Null()]),
    timedOut: Type.Boolean(),
    aborted: Type.Boolean(),
    stderr: Type.String(),
    stderrBytes: Type.Number(),
    stderrTruncated: Type.Boolean(),
    truncated: Type.Boolean(),
    fullOutputPath: Type.Optional(Type.String()),
  },
  { additionalProperties: false },
);

type AstGrepMatch = Static<typeof AstGrepMatchSchema>;
type AstGrepOutput = Static<typeof AstGrepOutputSchema>;

const ALLOWED_KEYS: Record<Operation, readonly string[]> = {
  search: [
    "operation",
    "pattern",
    "kind",
    "lang",
    "strictness",
    "selector",
    "paths",
    "globs",
    "limit",
    "format",
  ],
  rule: ["operation", "rule", "paths", "globs", "limit", "format"],
  debug: ["operation", "pattern", "lang", "debug"],
};

const SINGLE_LINE_CONTROL = /[\x00-\x1f\x7f]/;
// Patterns and YAML rules legitimately span lines, so only non-whitespace
// control characters are rejected there.
const OTHER_CONTROL = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/;

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function validateAllowedKeys(operation: Operation, params: AstGrepParams): void {
  const allowedKeys = ALLOWED_KEYS[operation];
  if (allowedKeys === undefined) {
    throw new Error(`unsupported operation: ${String(operation)}`);
  }
  const allowed = new Set(allowedKeys);
  for (const key of Object.keys(params)) {
    if (allowed.has(key)) continue;
    const fallback = operation === "search" ? ' (or set operation to "rule" or "debug")' : "";
    throw new Error(
      `Parameter "${key}" is not supported for operation "${operation}"${fallback}`,
    );
  }
}

function validateText(value: unknown, name: string, maxLength = MAX_TEXT_LENGTH): string {
  if (typeof value !== "string") {
    throw new Error(`"${name}" must be a string`);
  }
  if (value.trim().length === 0) {
    throw new Error(`"${name}" must not be empty`);
  }
  if (value.length > maxLength) {
    throw new Error(`"${name}" is too long (maximum ${maxLength} characters)`);
  }
  if (SINGLE_LINE_CONTROL.test(value)) {
    throw new Error(`"${name}" must not contain control characters`);
  }
  return value;
}

function validateMultilineText(value: unknown, name: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new Error(`"${name}" must be a string`);
  }
  if (value.trim().length === 0) {
    throw new Error(`"${name}" must not be empty`);
  }
  if (value.length > maxLength) {
    throw new Error(`"${name}" is too long (maximum ${maxLength} characters)`);
  }
  if (OTHER_CONTROL.test(value)) {
    throw new Error(`"${name}" must not contain control characters`);
  }
  return value;
}

// ast-grep parses the value of `-p`/`-k`/`--selector` with clap: a leading '-'
// would be read as a flag, so reject it with a clear message instead of letting
// the CLI fail later.
function validateSyntax(value: unknown, name: string): string {
  const syntax = validateMultilineText(value, name, MAX_TEXT_LENGTH);
  if (syntax.startsWith("-")) {
    throw new Error(`"${name}" must not start with '-'`);
  }
  return syntax;
}

function validatePath(value: unknown): string {
  if (typeof value !== "string") {
    throw new Error("paths must be strings");
  }
  if (value.length === 0) {
    throw new Error("paths must not contain an empty string");
  }
  if (value.length > MAX_TEXT_LENGTH) {
    throw new Error(`path is too long (maximum ${MAX_TEXT_LENGTH} characters)`);
  }
  if (SINGLE_LINE_CONTROL.test(value)) {
    throw new Error("paths must not contain control characters");
  }
  if (value.startsWith("/") || value.startsWith("\\") || /^[A-Za-z]:/.test(value)) {
    throw new Error(`absolute paths are not allowed: ${value}`);
  }
  if (value.split(/[\\/]+/).includes("..")) {
    throw new Error(`paths must not contain '..': ${value}`);
  }
  if (value.startsWith("-")) {
    throw new Error(`paths must not start with '-': ${value}`);
  }
  return value;
}

function validateGlob(value: unknown): string {
  const glob = validateText(value, "globs");
  if (glob.startsWith("-")) {
    throw new Error(`globs must not start with '-': ${glob}`);
  }
  if (glob.split(/[\\/]+/).includes("..")) {
    throw new Error(`globs must not contain '..': ${glob}`);
  }
  // ast-grep does not recognise a './' prefix in globs; strip it like the
  // built-in grep tool does so "./src/*.ts" still matches.
  const normalized = glob.replace(/^(!?)(?:\.\/)+/, "$1");
  if (normalized.length === 0 || normalized === "!") {
    throw new Error(`globs must not be empty: ${glob}`);
  }
  return normalized;
}

function validateRule(value: unknown): string {
  const rule = validateMultilineText(value, "rule", MAX_RULE_LENGTH);
  // Same argument-parser guard as the pattern: a rule rendered as a YAML list
  // (`- id: ...`) starts with '-' and would be read as a flag.
  if (rule.startsWith("-")) {
    throw new Error(`"rule" must not start with '-'`);
  }
  for (const field of ["id", "language", "rule"]) {
    if (!new RegExp(`^\\s*${field}\\s*:`, "m").test(rule)) {
      throw new Error(
        `"rule" must be an ast-grep YAML rule with top-level id, language, and rule fields (missing "${field}")`,
      );
    }
  }
  return rule;
}

function validateLimit(value: unknown): number {
  if (value === undefined) return DEFAULT_LIMIT;
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new Error(`"limit" must be an integer`);
  }
  if (value < 1 || value > MAX_LIMIT) {
    throw new Error(`"limit" must be between 1 and ${MAX_LIMIT}`);
  }
  return value;
}

function requireValue(value: string | undefined, name: string, operation: Operation): string {
  if (value === undefined) {
    throw new Error(`"${name}" is required for operation "${operation}"`);
  }
  return value;
}

export function buildAstGrepArgs(params: AstGrepParams, configPath: string): string[] {
  const operation = params.operation ?? "search";
  validateAllowedKeys(operation, params);
  // Validated here as well so the argument builder rejects everything the tool
  // contract rejects, and callers cannot silently pass an ignored value.
  validateLimit(params.limit);

  // Present on every operation: no implicit config discovery, no native
  // custom-language loading.
  const isolation = ["-c", configPath, "--custom-languages", "ignore"];

  const paths = (params.paths ?? []).map(validatePath);
  const globs = (params.globs ?? []).map(validateGlob);
  // Always spell out the search root: ast-grep's own default is ".". Explicit
  // positionals after `--` keep a path from ever being read as a flag.
  const targets = paths.length > 0 ? paths : ["."];

  switch (operation) {
    case "search": {
      if ((params.pattern === undefined) === (params.kind === undefined)) {
        throw new Error('operation "search" requires exactly one of "pattern" or "kind"');
      }
      if (params.selector !== undefined && params.pattern === undefined) {
        throw new Error('"selector" requires "pattern"');
      }
      if (params.strictness !== undefined && params.pattern === undefined) {
        throw new Error('"strictness" requires "pattern"');
      }

      // --json=stream needs the `=` form; `--json stream` would be parsed as
      // pretty JSON plus a path named "stream".
      const args = ["run", "--json=stream", "--color=never", ...isolation];
      if (params.pattern !== undefined) {
        args.push("-p", validateSyntax(params.pattern, "pattern"));
      }
      if (params.kind !== undefined) {
        args.push("-k", validateSyntax(params.kind, "kind"));
      }
      if (params.lang !== undefined) {
        args.push("-l", params.lang);
      }
      if (params.selector !== undefined) {
        args.push("--selector", validateSyntax(params.selector, "selector"));
      }
      if (params.strictness !== undefined) {
        args.push("--strictness", params.strictness);
      }
      for (const glob of globs) args.push("--globs", glob);
      args.push("--", ...targets);
      return args;
    }

    case "rule": {
      const rule = validateRule(requireValue(params.rule, "rule", operation));
      const args = ["scan", "--json=stream", "--color=never", ...isolation, "--inline-rules", rule];
      for (const glob of globs) args.push("--globs", glob);
      args.push("--", ...targets);
      return args;
    }

    case "debug": {
      const pattern = validateSyntax(requireValue(params.pattern, "pattern", operation), "pattern");
      const lang = requireValue(params.lang, "lang", operation);
      // --debug-query prints the parsed pattern to stderr and then runs the
      // search. --stdin with an empty stream keeps it from touching the
      // filesystem: nothing matches, so only the AST is produced.
      return [
        "run",
        `--debug-query=${params.debug ?? "ast"}`,
        "--color=never",
        ...isolation,
        "-l",
        lang,
        "-p",
        pattern,
        "--stdin",
      ];
    }

    default:
      throw new Error(`unsupported operation: ${String(operation)}`);
  }
}

function buildEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    // Ambient ast-grep settings and colour overrides would make the tool
    // contract depend on the caller's environment.
    if (key.startsWith("AST_GREP_")) continue;
    if (
      key === "NO_COLOR" ||
      key === "FORCE_COLOR" ||
      key === "CLICOLOR" ||
      key === "CLICOLOR_FORCE" ||
      key === "TERM"
    ) {
      continue;
    }
    env[key] = value;
  }
  env.NO_COLOR = "1";
  return env;
}

interface RunResult extends CaptureResult {
  matches: AstGrepMatch[];
  limitReached: boolean;
  parseErrors: number;
}

interface RawMatch {
  file?: unknown;
  text?: unknown;
  language?: unknown;
  ruleId?: unknown;
  severity?: unknown;
  message?: unknown;
  range?: {
    start?: { line?: unknown; column?: unknown };
    end?: { line?: unknown; column?: unknown };
  };
  metaVariables?: { single?: Record<string, { text?: unknown }> };
}

function asInteger(value: unknown): number | undefined {
  return typeof value === "number" && Number.isInteger(value) ? value : undefined;
}

// ast-grep uses 0-based LSP-style positions; the tool reports 1-based ones so
// they line up with the `read`/`grep` tools and with editor output.
function normalizeMatch(raw: RawMatch): AstGrepMatch | undefined {
  if (typeof raw.file !== "string" || typeof raw.text !== "string") return undefined;
  const startLine = asInteger(raw.range?.start?.line);
  const startColumn = asInteger(raw.range?.start?.column);
  if (startLine === undefined || startColumn === undefined) return undefined;
  const endLine = asInteger(raw.range?.end?.line) ?? startLine;
  const endColumn = asInteger(raw.range?.end?.column) ?? startColumn;

  const metaVariables: Record<string, string> = {};
  for (const [name, variable] of Object.entries(raw.metaVariables?.single ?? {})) {
    if (typeof variable?.text === "string") metaVariables[name] = variable.text;
  }

  const match: AstGrepMatch = {
    file: raw.file,
    startLine: startLine + 1,
    startColumn: startColumn + 1,
    endLine: endLine + 1,
    endColumn: endColumn + 1,
    text: raw.text,
  };
  if (typeof raw.language === "string") match.language = raw.language;
  if (typeof raw.ruleId === "string") match.ruleId = raw.ruleId;
  if (typeof raw.severity === "string") match.severity = raw.severity;
  if (typeof raw.message === "string") match.message = raw.message;
  if (Object.keys(metaVariables).length > 0) match.metaVariables = metaVariables;
  return match;
}

async function runAstGrep(
  argv: string[],
  cwd: string,
  signal: AbortSignal | undefined,
  options: { json: boolean; limit: number },
): Promise<RunResult> {
  const matches: AstGrepMatch[] = [];
  let parseErrors = 0;
  let limitReached = false;

  const result = await capture({
    executable: "ast-grep",
    argv,
    cwd,
    env: buildEnv(),
    timeoutMs: TIMEOUT_MS,
    tempPrefix: TEMP_PREFIX,
    signal,
    ...(options.json
      ? {
          onStdoutLine: (line: string): boolean | void => {
            if (limitReached || line.trim().length === 0) return;
            let raw: RawMatch;
            try {
              raw = JSON.parse(line) as RawMatch;
            } catch {
              parseErrors++;
              return;
            }
            const match = normalizeMatch(raw);
            if (match === undefined) {
              parseErrors++;
              return;
            }
            if (matches.length >= options.limit) {
              // One match past the limit proves the result set is incomplete,
              // so the notice is accurate instead of merely "maybe more".
              limitReached = true;
              return false;
            }
            matches.push(match);
          },
        }
      : {}),
  });

  return { ...result, matches, limitReached, parseErrors };
}

function compareMatches(a: AstGrepMatch, b: AstGrepMatch): number {
  // ast-grep walks directories in parallel, so stream order is not stable.
  // Sorting keeps the result deterministic (prompt caching, idempotent calls).
  if (a.file !== b.file) return a.file < b.file ? -1 : 1;
  if (a.startLine !== b.startLine) return a.startLine - b.startLine;
  return a.startColumn - b.startColumn;
}

function formatMatch(match: AstGrepMatch): string {
  const text = match.text.replace(/\s+$/u, "");
  const textLines = text.split("\n");
  const header =
    `${match.file}:${match.startLine}:${match.startColumn}` +
    (textLines.length > 1 ? `-${match.endLine}` : "");

  if (textLines.length === 1) {
    return `${header}: ${truncateLine(textLines[0]).text}`;
  }

  const shown = textLines
    .slice(0, MAX_MATCH_LINES)
    .map((line) => `  ${truncateLine(line.replace(/\s+$/u, "")).text}`);
  if (textLines.length > MAX_MATCH_LINES) {
    shown.push(`  ... ${textLines.length - MAX_MATCH_LINES} more lines`);
  }
  return [`${header}:`, ...shown].join("\n");
}

export function formatMatches(
  matches: AstGrepMatch[],
  summary: { limit: number; limitReached: boolean },
): string {
  if (matches.length === 0) return "no matches";

  const fileCount = new Set(matches.map((match) => match.file)).size;
  const header =
    `${matches.length} match${matches.length === 1 ? "" : "es"} in ` +
    `${fileCount} file${fileCount === 1 ? "" : "s"}` +
    (summary.limitReached
      ? ` (limit ${summary.limit} reached; more matches exist — narrow paths or globs, refine the pattern, or raise limit)`
      : "");

  const body = [...matches].sort(compareMatches).map(formatMatch).join("\n");
  return `${header}\n\n${body}`;
}

function buildSuccessContent(params: AstGrepParams, run: RunResult, limit: number): string {
  const operation = params.operation ?? "search";
  if (operation === "debug") {
    // The parsed AST itself is written to stderr by ast-grep; treat it as the
    // payload and keep stdout (normally empty for --stdin) as a fallback.
    const sections: string[] = [];
    const ast = run.stderr.trimEnd();
    if (ast.length > 0) sections.push(ast);
    if (run.stderrTruncated) sections.push("[debug output truncated]");
    const stdout = run.stdoutHead.trimEnd();
    if (stdout.length > 0) sections.push(stdout);
    return sections.length > 0 ? sections.join("\n\n") : "(no debug output)";
  }

  const sections = [
    formatMatches(run.matches, { limit, limitReached: run.limitReached }),
  ];
  // A rule's message/severity is the whole point of `scan`; show it with the
  // match instead of hiding it in the structured details.
  if (run.matches.some((match) => match.ruleId !== undefined)) {
    const annotated = run.matches
      .filter((match) => match.ruleId !== undefined)
      .map((match) => `[${match.severity ?? "info"}] ${match.ruleId}: ${match.message ?? ""}`.trimEnd());
    sections.push([...new Set(annotated)].join("\n"));
  }
  const stderr = run.stderr.trimEnd();
  if (stderr.length > 0) sections.push(`[stderr]\n${stderr}`);
  if (run.stderrTruncated) sections.push("[stderr truncated]");
  if (run.parseErrors > 0) {
    sections.push(`[${run.parseErrors} unparsable ast-grep output line(s) ignored]`);
  }
  return sections.join("\n\n");
}

function buildFailureContent(params: AstGrepParams, run: RunResult): string {
  const operation = params.operation ?? "search";
  const header = run.timedOut
    ? `ast-grep ${operation} timed out after ${TIMEOUT_MS / 1000}s`
    : run.aborted
      ? `ast-grep ${operation} was cancelled`
      : `ast-grep ${operation} failed (${
          run.exitCode !== null ? `exit ${run.exitCode}` : `signal ${run.signal ?? "unknown"}`
        })`;
  const sections = [header];
  const stderr = run.stderr.trimEnd();
  const stdout = run.stdoutHead.trimEnd();
  if (stderr.length > 0) sections.push(stderr);
  if (stdout.length > 0) sections.push(stdout);
  if (run.stderrTruncated) sections.push("[stderr truncated]");
  return sections.join("\n\n");
}

// ast-grep reports "no matches" as exit code 1. A real failure also exits 1 in
// some cases, so the diagnostic prefix decides: anyhow prints "Error: ".
const LOOKS_LIKE_ERROR = /(^|\n)\s*(error|Error)\s*[:\[]/;

function errorResult(
  operation: Operation,
  argv: string[],
  message: string,
  aborted = false,
): {
  content: [{ type: "text"; text: string }];
  details: AstGrepOutput;
  structuredContent: AstGrepOutput;
  isError: true;
} {
  const details: AstGrepOutput = {
    operation,
    argv,
    content: message,
    matchCount: 0,
    fileCount: 0,
    limitReached: false,
    matches: [],
    exitCode: null,
    signal: null,
    timedOut: false,
    aborted,
    stderr: "",
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

// SDK subagents reuse the exact same validation and execution path.
export function createAstGrepTool() {
  return defineTool<typeof AstGrepParamsSchema, AstGrepOutput>({
    name: "ast_grep",
    label: "Structural search (ast-grep)",
    description:
      "Search code by syntax structure with ast-grep. Use it when the shape of the code matters (call sites, declarations, imports, a specific API usage) rather than plain text. Operations: search (ast-grep pattern or node kind), rule (inline YAML rule with relational conditions), debug (print how a pattern parses, to fix a pattern that matches nothing). Read-only: it never rewrites files. Respects .gitignore.",
    promptSnippet:
      "Structural code search by AST pattern, node kind, or YAML rule (read-only, respects .gitignore).",
    promptGuidelines: [
      "Use ast_grep instead of grep when the search depends on syntax structure, e.g. `await fetch($URL)` or `class $NAME extends $BASE`, and use grep for plain text.",
      'When an ast_grep pattern matches nothing unexpectedly, call ast_grep with operation "debug" to see how the pattern parses before rewriting it blindly.',
      'Use ast_grep with operation "rule" and an inline YAML rule when a pattern cannot express the condition (inside/has/precedes/follows).',
    ],
    parameters: AstGrepParamsSchema,
    outputSchema: AstGrepOutputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const operation = params.operation ?? "search";
      let argv: string[];
      try {
        argv = buildAstGrepArgs(params, getNeutralConfigPath());
      } catch (error) {
        throw new Error(`Invalid ast_grep tool arguments: ${errorMessage(error)}`);
      }

      if (signal?.aborted) {
        return errorResult(operation, argv, "ast_grep tool call was cancelled", true);
      }

      const limit = validateLimit(params.limit);
      let run: RunResult;
      try {
        run = await runAstGrep(argv, ctx.cwd, signal, {
          json: operation !== "debug",
          limit,
        });
      } catch (error) {
        const code = (error as NodeJS.ErrnoException).code;
        const message =
          code === "ENOENT"
            ? "ast-grep is not installed or not on PATH. Apply the home-manager configuration so `ast-grep` is available."
            : `Failed to run ast-grep: ${errorMessage(error)}`;
        return errorResult(operation, argv, message);
      }

      const noMatches =
        run.exitCode === 1 &&
        run.matches.length === 0 &&
        run.stdoutHead.trim().length === 0 &&
        !LOOKS_LIKE_ERROR.test(run.stderr);
      // Reaching the limit kills the child on purpose; that is not a failure.
      const failed =
        !noMatches &&
        !run.limitReached &&
        (run.exitCode !== 0 ||
          run.exitCode === null ||
          run.timedOut ||
          run.aborted ||
          run.signal !== null);

      const truncatedContent = truncateHead(
        failed ? buildFailureContent(params, run) : buildSuccessContent(params, run, limit),
        { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES },
      );

      let fullOutputPath = run.fullStdoutPath;
      let content = truncatedContent.content;
      if (truncatedContent.truncated) {
        if (fullOutputPath !== undefined) {
          appendStderrToOutput(fullOutputPath, run.stderr, run.stderrTruncated);
        } else {
          fullOutputPath = writeTempOutput(TEMP_PREFIX, truncatedContent.content);
        }
        content +=
          `\n\n[Output truncated (${truncatedContent.totalLines} lines, ` +
          `${formatSize(truncatedContent.totalBytes)}). Full output: ${fullOutputPath}]`;
      } else if (fullOutputPath !== undefined) {
        content += `\n\n[Full output: ${fullOutputPath}]`;
      }

      const details: AstGrepOutput = {
        operation,
        argv,
        content,
        matchCount: run.matches.length,
        fileCount: new Set(run.matches.map((match) => match.file)).size,
        limitReached: run.limitReached,
        matches: [...run.matches].sort(compareMatches),
        exitCode: run.exitCode,
        signal: run.signal,
        timedOut: run.timedOut,
        aborted: run.aborted,
        stderr: run.stderr.trimEnd(),
        stderrBytes: run.stderrBytes,
        stderrTruncated: run.stderrTruncated,
        truncated: truncatedContent.truncated,
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

export default function astGrepExtension(pi: ExtensionAPI): void {
  pi.registerTool(createAstGrepTool());
}

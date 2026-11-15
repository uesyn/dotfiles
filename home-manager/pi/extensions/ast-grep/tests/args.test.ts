import assert from "node:assert/strict";
import { test } from "node:test";
import { buildAstGrepArgs } from "../index.ts";

// The tool passes an explicit empty config and denies native custom languages on
// every operation; tests use a fixed path so argv is comparable.
const CONFIG = "/tmp/pi-ast-grep-test/sgconfig.yml";
const ISOLATION = ["-c", CONFIG, "--custom-languages", "ignore"];
const WRITE_FLAGS = ["-r", "--rewrite", "-U", "--update-all", "-i", "--interactive"];

function args(params: Parameters<typeof buildAstGrepArgs>[0]): string[] {
  return buildAstGrepArgs(params, CONFIG);
}

function assertReadOnly(argv: string[]): void {
  for (const flag of WRITE_FLAGS) {
    assert.ok(
      !argv.includes(flag) && !argv.some((arg) => arg.startsWith(`${flag}=`)),
      `argv must not contain the rewrite flag ${flag}: ${JSON.stringify(argv)}`,
    );
  }
}

function assertConfigIsolated(argv: string[]): void {
  // No implicit sgconfig.yml discovery and no native custom-language loading.
  assert.deepEqual(argv.slice(argv.indexOf("-c"), argv.indexOf("-c") + 4), ISOLATION);
  assert.equal(argv.filter((arg) => arg === "-c").length, 1);
  assert.ok(!argv.includes("allow") && !argv.includes("trust"));
}

test("search builds a deterministic, streaming run command", () => {
  const argv = args({ pattern: "await fetch($URL)", lang: "ts" });
  assert.deepEqual(argv, [
    "run",
    "--json=stream",
    "--color=never",
    ...ISOLATION,
    "-p",
    "await fetch($URL)",
    "-l",
    "ts",
    "--",
    ".",
  ]);
  assertReadOnly(argv);
  assertConfigIsolated(argv);
});

test("search supports node kinds, strictness, selector and globs", () => {
  const argv = args({
    pattern: "foo($NAME)",
    kind: undefined,
    selector: "identifier",
    strictness: "relaxed",
    globs: ["./src/**/*.ts", "!**/test/**"],
    paths: ["src", "internal"],
    limit: 5,
  });
  assert.deepEqual(argv, [
    "run",
    "--json=stream",
    "--color=never",
    ...ISOLATION,
    "-p",
    "foo($NAME)",
    "--selector",
    "identifier",
    "--strictness",
    "relaxed",
    "--globs",
    "src/**/*.ts",
    "--globs",
    "!**/test/**",
    "--",
    "src",
    "internal",
  ]);
  assertReadOnly(argv);
  assertConfigIsolated(argv);

  const kind = args({ kind: "call_expression > identifier" });
  assert.deepEqual(kind, [
    "run",
    "--json=stream",
    "--color=never",
    ...ISOLATION,
    "-k",
    "call_expression > identifier",
    "--",
    ".",
  ]);
});

test("search requires exactly one of pattern and kind", () => {
  assert.throws(() => args({}), /exactly one of "pattern" or "kind"/);
  assert.throws(() => args({ pattern: "foo()", kind: "call_expression" }), /exactly one of "pattern" or "kind"/);
  assert.throws(() => args({ kind: "call_expression", selector: "identifier" }), /"selector" requires "pattern"/);
  assert.throws(() => args({ kind: "call_expression", strictness: "ast" }), /"strictness" requires "pattern"/);
});

test("patterns can span lines but must not start with '-'", () => {
  assert.throws(() => args({ pattern: "-p foo" }), /must not start with '-'/);
  assert.throws(() => args({ pattern: "   " }), /must not be empty/);
  assert.throws(() => args({ pattern: "foo\u0000bar" }), /control characters/);
  assert.throws(() => args({ pattern: "x".repeat(4097) }), /too long/);

  const multiline = args({ pattern: "if err != nil {\n\treturn err\n}", lang: "go", paths: ["."] });
  assert.equal(multiline[multiline.indexOf("-p") + 1], "if err != nil {\n\treturn err\n}");
});

test("shell metacharacters stay inside one argv element", () => {
  const hostile = "$(touch /tmp/pwned); `id`; rm -rf /; ${HOME} | cat > /tmp/x";
  const argv = args({ pattern: hostile, lang: "ts" });
  // Exactly one element carries the payload: nothing is split or interpolated,
  // and no shell is involved (spawn is called with shell: false).
  assert.deepEqual(argv.filter((arg) => arg === hostile), [hostile]);
  assert.equal(argv.filter((arg) => arg.includes("pwned")).length, 1);

  const rule = ["id: x", "language: TypeScript", "rule:", `  pattern: foo()`, "message: $(id)"].join("\n");
  const ruleArgv = args({ operation: "rule", rule });
  assert.deepEqual(ruleArgv.filter((arg) => arg === rule), [rule]);
});

test("paths are repository-relative and never read as flags", () => {
  for (const path of ["/etc/passwd", "C:\\tmp", "../outside", "src/../../etc", "-rf"]) {
    assert.throws(() => args({ pattern: "foo()", paths: [path] }));
  }
  assert.throws(() => args({ pattern: "foo()", paths: [""] }));
  assert.throws(() => args({ pattern: "foo()", paths: ["a\u0007b"] }));
});

test("globs are normalized and cannot be empty", () => {
  assert.throws(() => args({ pattern: "foo()", globs: ["-x"] }), /must not start with '-'/);
  assert.throws(() => args({ pattern: "foo()", globs: ["./"] }), /must not be empty/);
  assert.throws(() => args({ pattern: "foo()", globs: ["../up"] }), /must not contain '\.\.'/);
  const argv = args({ pattern: "foo()", globs: ["!./dist/**"] });
  assert.ok(argv.includes("!dist/**"));
});

test("rule builds an inline-rules scan", () => {
  const rule = [
    "id: no-await-in-loop",
    "language: TypeScript",
    "rule:",
    "  pattern: await $A",
    "  inside:",
    "    kind: for_statement",
    "    stopBy: end",
  ].join("\n");
  const argv = args({ operation: "rule", rule, paths: ["src"] });
  assert.deepEqual(argv.slice(0, 8), [
    "scan",
    "--json=stream",
    "--color=never",
    ...ISOLATION,
    "--inline-rules",
  ]);
  assert.equal(argv[8], rule);
  assert.deepEqual(argv.slice(-2), ["--", "src"]);
  assertReadOnly(argv);
  assertConfigIsolated(argv);
});

test("rule requires id, language and rule fields", () => {
  assert.throws(() => args({ operation: "rule" }), /"rule" is required/);
  assert.throws(
    () => args({ operation: "rule", rule: "language: TypeScript\nrule: {pattern: foo}" }),
    /missing "id"/,
  );
  assert.throws(
    () => args({ operation: "rule", rule: "id: x\nrule: {pattern: foo}" }),
    /missing "language"/,
  );
  assert.throws(
    () => args({ operation: "rule", rule: "id: x\nlanguage: TypeScript" }),
    /missing "rule"/,
  );
  // A YAML list form starts with '-' and would be read as a flag.
  assert.throws(
    () => args({ operation: "rule", rule: "- id: x\n  language: TypeScript\n  rule: {pattern: foo}" }),
    /must not start with '-'/,
  );
});

test("debug prints the parsed pattern and never searches files", () => {
  const argv = args({ operation: "debug", pattern: "foo($$$A)", lang: "ts" });
  assert.deepEqual(argv, [
    "run",
    "--debug-query=ast",
    "--color=never",
    ...ISOLATION,
    "-l",
    "ts",
    "-p",
    "foo($$$A)",
    // --stdin with an empty stream: ast-grep prints the AST and searches
    // nothing, so no file is touched.
    "--stdin",
  ]);
  assert.ok(!argv.includes("--json=stream"));
  assert.ok(!argv.includes("--"));
  assertConfigIsolated(argv);
  assert.throws(() => args({ operation: "debug", pattern: "foo()" }), /"lang" is required/);
  assert.throws(() => args({ operation: "debug", lang: "ts" }), /"pattern" is required/);

  const sexp = args({ operation: "debug", pattern: "foo()", lang: "ts", debug: "sexp" });
  assert.ok(sexp.includes("--debug-query=sexp"));
});

test("an operation only accepts its own parameters", () => {
  assert.throws(
    () => args({ operation: "rule", pattern: "foo()" }),
    /Parameter "pattern" is not supported for operation "rule"/,
  );
  assert.throws(
    () => args({ operation: "debug", pattern: "foo()", lang: "ts", limit: 5 }),
    /Parameter "limit" is not supported for operation "debug"/,
  );
  assert.throws(() => args({ operation: "nope" } as never), /unsupported operation/);
});

test("limit is bounded", () => {
  assert.throws(() => args({ pattern: "foo()", limit: 0 }), /between 1 and 500/);
  assert.throws(() => args({ pattern: "foo()", limit: 501 }), /between 1 and 500/);
  assert.throws(() => args({ pattern: "foo()", limit: 1.5 }), /must be an integer/);
});

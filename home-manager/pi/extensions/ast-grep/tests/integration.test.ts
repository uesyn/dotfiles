import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { access, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { createAstGrepTool } from "../index.ts";

const available = spawnSync("ast-grep", ["--version"], { encoding: "utf8" }).status === 0;
const skip = available ? false : "ast-grep is not installed";

const tool = createAstGrepTool();

function context(cwd: string) {
  return { cwd } as never;
}

async function fixture(): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), "pi-ast-grep-test-"));
  await writeFile(
    join(dir, "a.ts"),
    ["export async function load(url: string) {", "  await fetch(url);", "  await fetch(url + '?x');", "}", ""].join("\n"),
  );
  await writeFile(join(dir, "b.ts"), "const untouched = 1;\n");
  return dir;
}

test("search returns streamed matches as sorted path:line:column text", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "search",
      { pattern: "await fetch($URL)", lang: "ts", paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 2);
    assert.equal(result.details.fileCount, 1);
    assert.equal(result.details.exitCode, 0);
    assert.match(result.content[0].text, /^2 matches in 1 file/);
    assert.match(result.content[0].text, /a\.ts:2:3: await fetch\(url\)/);
    assert.deepEqual(result.details.matches[0].metaVariables, { URL: "url" });
    // No rewrite flag may ever reach ast-grep.
    for (const flag of ["-r", "--rewrite", "-U", "--update-all", "-i", "--interactive"]) {
      assert.ok(!result.details.argv.includes(flag));
    }
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a limit stops the stream and reports that more matches exist", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "limit",
      { pattern: "await fetch($URL)", lang: "ts", paths: ["a.ts"], limit: 1 },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 1);
    assert.equal(result.details.limitReached, true);
    assert.match(result.content[0].text, /limit 1 reached/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("omitting lang infers the language from file extensions", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "infer",
      { pattern: "await fetch($URL)", paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 2);
    assert.equal(result.details.matches[0].language, "TypeScript");
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("no matches is reported as a successful empty result", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "none",
      { pattern: "totallyAbsentCall($$$A)", lang: "ts", paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 0);
    assert.equal(result.content[0].text, "no matches");
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("debug prints the parsed pattern instead of searching", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "debug",
      { operation: "debug", pattern: "await fetch($URL)", lang: "ts", debug: "ast" },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.match(result.content[0].text, /Debug AST/);
    assert.match(result.content[0].text, /call_expression|await_expression/);
    assert.deepEqual(result.details.matches, []);
    assert.ok(result.details.argv.includes("--stdin"));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("rule runs an inline YAML rule with relational conditions", { skip }, async () => {
  const dir = await fixture();
  try {
    const rule = [
      "id: fetch-in-function",
      "language: TypeScript",
      "severity: warning",
      "message: fetch inside a function",
      "rule:",
      "  pattern: await fetch($$$ARGS)",
    ].join("\n");
    const result = await tool.execute(
      "rule",
      { operation: "rule", rule, paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 2);
    assert.equal(result.details.matches[0].ruleId, "fetch-in-function");
    assert.equal(result.details.matches[0].severity, "warning");
    assert.match(result.content[0].text, /\[warning\] fetch-in-function/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a malformed pattern surfaces ast-grep's warning instead of failing", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "bad",
      { pattern: "function (", lang: "ts", paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    // ast-grep parses the broken pattern with an ERROR node and exits 0.
    assert.equal(result.isError, false);
    assert.match(result.content[0].text, /Warning: Pattern contains an ERROR node/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a CLI error such as an unsupported language is a tool error", { skip }, async () => {
  const dir = await fixture();
  try {
    const result = await tool.execute(
      "lang",
      { pattern: "await fetch($URL)", lang: "nope" as never, paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, true);
    assert.equal(result.details.exitCode, 2);
    assert.match(result.content[0].text, /failed \(exit 2\)/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a repository sgconfig.yml cannot remap languages or load native libraries", { skip }, async () => {
  const dir = await mkdtemp(join(tmpdir(), "pi-ast-grep-config-test-"));
  try {
    // Discovery walks up from the working directory, so a repo-controlled file
    // would otherwise change how files are parsed.
    await writeFile(join(dir, "sgconfig.yml"), "languageGlobs:\n  TypeScript:\n    - '*.txt'\n");
    await writeFile(join(dir, "code.txt"), "const a = await fetch(url);\n");

    // Control: the raw CLI honours the file and treats code.txt as TypeScript.
    const raw = spawnSync(
      "ast-grep",
      ["run", "--json=stream", "--color=never", "-p", "await fetch($URL)", "-l", "ts", "--", "code.txt"],
      { cwd: dir, encoding: "utf8" },
    );
    assert.equal(raw.status, 0);
    assert.match(raw.stdout, /code\.txt/);

    // The tool pins its own empty config, so the file is not TypeScript here.
    const result = await tool.execute(
      "isolated",
      { pattern: "await fetch($URL)", lang: "ts", paths: ["code.txt"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 0);
    assert.ok(result.details.argv.includes("--custom-languages"));
    assert.equal(result.details.argv[result.details.argv.indexOf("--custom-languages") + 1], "ignore");
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a project config that asks for a native custom language is never parsed", { skip }, async () => {
  const dir = await mkdtemp(join(tmpdir(), "pi-ast-grep-native-test-"));
  try {
    // Native custom languages execute code with the user's permissions. Whatever
    // the schema, the tool must not read the file at all, so even an invalid one
    // must not change the result.
    await writeFile(
      join(dir, "sgconfig.yml"),
      [
        "customLanguages:",
        "  - languageId: evil",
        "    libraryPath: /nonexistent/libevil.so",
        "    extensions: [txt]",
        "",
      ].join("\n"),
    );
    await writeFile(join(dir, "a.ts"), "const a = await fetch(url);\n");

    // Control: the raw CLI parses the file and fails on it.
    const raw = spawnSync("ast-grep", ["run", "-p", "foo()", "-l", "ts", "--", "a.ts"], {
      cwd: dir,
      encoding: "utf8",
    });
    assert.notEqual(raw.status, 0);

    const result = await tool.execute(
      "native",
      { pattern: "await fetch($URL)", lang: "ts", paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, false);
    assert.equal(result.details.matchCount, 1);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("shell metacharacters in a pattern never reach a shell", { skip }, async () => {
  const dir = await fixture();
  try {
    const pwned = join(dir, "pwned");
    const result = await tool.execute(
      "metachars",
      { pattern: `$(touch ${pwned}); \`touch ${pwned}\`; touch ${pwned} | cat`, lang: "ts", paths: ["a.ts"] },
      undefined,
      undefined,
      context(dir),
    );
    // ast-grep rejects the pattern as invalid syntax; the important part is that
    // nothing was executed.
    await assert.rejects(access(pwned));
    assert.equal(result.details.matchCount, 0);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a cancelled call never spawns or reports success", { skip }, async () => {
  const dir = await fixture();
  try {
    const controller = new AbortController();
    controller.abort();
    const result = await tool.execute(
      "abort",
      { pattern: "await fetch($URL)", lang: "ts", paths: ["a.ts"] },
      controller.signal,
      undefined,
      context(dir),
    );
    assert.equal(result.isError, true);
    assert.equal(result.details.aborted, true);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

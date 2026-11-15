import assert from "node:assert/strict";
import { test } from "node:test";
import { formatMatches } from "../index.ts";

function match(overrides: Record<string, unknown>) {
  return {
    file: "src/a.ts",
    startLine: 1,
    startColumn: 1,
    endLine: 1,
    endColumn: 1,
    text: "x",
    ...overrides,
  } as never;
}

test("single-line matches use the path:line:column shape of the grep tool", () => {
  const text = formatMatches(
    [match({ file: "src/a.ts", startLine: 12, startColumn: 5, text: "await foo(bar)" })],
    { limit: 100, limitReached: false },
  );
  assert.equal(text, "1 match in 1 file\n\nsrc/a.ts:12:5: await foo(bar)");
});

test("multi-line matches are rendered as a header plus an indented block", () => {
  const text = formatMatches(
    [
      match({
        file: "src/a.go",
        startLine: 40,
        startColumn: 2,
        endLine: 42,
        text: "if err != nil {\n\t\treturn err\n\t}",
      }),
    ],
    { limit: 100, limitReached: false },
  );
  assert.equal(
    text,
    ["1 match in 1 file", "", "src/a.go:40:2-42:", "  if err != nil {", "  \t\treturn err", "  \t}"].join("\n"),
  );
});

test("matches are grouped and sorted by file, line and column", () => {
  const text = formatMatches(
    [
      match({ file: "src/b.ts", startLine: 4 }),
      match({ file: "src/a.ts", startLine: 9 }),
      match({ file: "src/a.ts", startLine: 2, startColumn: 7 }),
      match({ file: "src/a.ts", startLine: 2, startColumn: 3 }),
    ],
    { limit: 100, limitReached: false },
  );
  assert.deepEqual(
    text.split("\n").slice(2),
    ["src/a.ts:2:3: x", "src/a.ts:2:7: x", "src/a.ts:9:1: x", "src/b.ts:4:1: x"],
  );
});

test("a reached limit is reported with the way out", () => {
  const text = formatMatches([match({})], { limit: 5, limitReached: true });
  assert.match(text, /1 match in 1 file \(limit 5 reached; more matches exist/);
});

test("no matches is a success value, not an empty string", () => {
  assert.equal(formatMatches([], { limit: 100, limitReached: false }), "no matches");
});

test("long lines and tall matches are bounded per match", () => {
  const long = formatMatches([match({ text: "a".repeat(900) })], {
    limit: 100,
    limitReached: false,
  });
  const longLine = long.split("\n")[2];
  // 500 chars of text plus the truncation suffix and the path:line:column header.
  assert.ok(longLine.length < 540, `line should be truncated to 500 chars: ${longLine.length}`);
  assert.match(longLine, /\.\.\. \[truncated\]$/);

  const tall = formatMatches(
    [match({ text: Array.from({ length: 30 }, (_, index) => `line ${index}`).join("\n") })],
    { limit: 100, limitReached: false },
  );
  const lines = tall.split("\n");
  assert.equal(lines.length, 2 + 1 + 20 + 1, "header, match header, 20 lines, ellipsis");
  assert.equal(lines.at(-1), "  ... 10 more lines");
});

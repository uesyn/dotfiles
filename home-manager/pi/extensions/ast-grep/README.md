# Structural search (`ast_grep`)

Read-only structural code search on top of [ast-grep](https://ast-grep.github.io/).
The binary comes from `home-manager/default.nix` (`pkgs.ast-grep`); this
extension only wraps it, so `ast-grep` must be on `PATH`.

```text
ast_grep({ pattern: "await fetch($URL)", lang: "ts", paths: ["src"] })
ast_grep({ kind: "function_declaration[name=foo]", globs: ["src/**/*.ts"] })
ast_grep({ operation: "rule", rule: "id: x\nlanguage: TypeScript\nrule:\n  pattern: foo()" })
ast_grep({ operation: "debug", pattern: "class $NAME { $$$BODY }", lang: "ts" })
```

## Contract

- **Read-only.** No rewrite flag is ever emitted (`-r`, `--rewrite`, `-U`,
  `--update-all`, `-i`, `--interactive`). Rewriting stays with `write`/`edit`,
  so the tool can stay active in plan mode and in read-only subagents.
- **argv only.** Every argument is one `spawn` element; no shell. Paths always
  follow `--`, are repository-relative, and reject absolute paths, `..`,
  leading `-`, and control characters. A pattern, kind, or selector starting
  with `-` is rejected before ast-grep's parser can read it as a flag.
- **Closed language set.** `lang` is a `StringEnum` of ast-grep's built-in
  aliases, so typos fail with a tool error instead of a CLI error. Omitting it
  lets ast-grep infer the language per file extension. Custom
  `languageGlobs` grammars need a shared library on disk and are unsupported.
- **No ambient configuration.** `AST_GREP_*` and the colour variables are
  removed from the child environment.
- **Project configuration is neutralised.** Every invocation passes `-c` with an
  empty `sgconfig.yml` this extension writes to a private temporary directory,
  plus `--custom-languages ignore`. ast-grep discovers `sgconfig.yml` by walking
  up from the working directory, so a repository — or any ancestor directory,
  including `$HOME` — could otherwise inject `languageGlobs` (remapping which
  files are parsed as which language) or `customLanguages` + `libraryPath`,
  which makes ast-grep `dlopen` a native library. ast-grep warns that native
  custom languages "execute code with your permissions" and keeps a trust store
  for that reason, so the tool refuses them instead of relying on the default.
  Both config-file and trust-store discovery are skipped as a result; a project
  that wants its `sgconfig.yml` rules must run `ast-grep` through `bash`.
- **No symlink traversal.** `--follow` is never passed, so directory symlinks
  are not traversed. Naming a symlink in `paths` still reads its target, the
  same as the `read`/`grep` tools.
- **PATH, not a store path.** An outer nono profile (and its exec gate) therefore
  still applies. Pi itself runs outside nono, so this tool is unsandboxed like
  `read`/`grep`.

## Output

`--json=stream` is parsed line by line and rendered like `grep` so the model can
feed the location straight into `read`:

```text
2 matches in 1 file

src/a.ts:2:3: await fetch(url)
src/a.go:40:2-42:
  if err != nil {
    return err
  }
```

- Positions are converted from ast-grep's 0-based LSP convention to 1-based.
- Matches are sorted by file, line, and column. ast-grep walks directories in
  parallel, so stream order alone is not deterministic.
- `limit` (default 100, max 500) kills the stream after one extra match, which
  proves the "more matches exist" notice instead of guessing. A limit kill is a
  success, not a failure.
- Each match shows up to 20 lines and each line is capped at 500 characters;
  the whole result goes through `truncateHead` and spills the full text to a
  private temporary file with `fullOutputPath` in the details.
- `format: "json"` keeps the text content and puts the same matches in
  `structuredContent` (`file`, `startLine`, `startColumn`, `endLine`,
  `metaVariables`, and `ruleId`/`severity`/`message` for rule matches).
- Exit codes: `0` matches found, `1` no matches (still success), `2` invalid CLI
  input (error). A malformed pattern is *not* an error: ast-grep parses it with
  an `ERROR` node, exits `0`, and its warning is surfaced — that is the signal
  to run `operation: "debug"`.

## `debug`

`ast-grep run --debug-query=<mode>` prints the parsed pattern (not the target
code) and then keeps searching. The tool adds `--stdin` with an empty stream so
the search touches nothing, and reads the AST from stderr, where ast-grep writes
it:

```text
Debug AST:
program (0,0)-(0,17)
  expression_statement (0,0)-(0,17)
    await_expression (0,0)-(0,17)
      call_expression (0,6)-(0,17)
        function: identifier (0,6)-(0,11)
```

Use it when a pattern matches nothing. Passing a code snippet as `pattern` is
also the way to inspect how existing code parses. Some grammars only accept a
pattern in context: a Nix `a = b;` binding is not a top-level expression, so
`home.packages = $V` parses as an `apply_expression` and matches nothing. Reach
for `kind` (e.g. `binding`) or an enclosing pattern in those languages, and use
`debug` to see which node you actually got.

## Wiring

- `home-manager/pi/default.nix`: `settings.extensions` entry and
  `defaultTools` `"+ast_grep"`.
- `subagent/runner.ts`: `createAstGrepTool()` is added to the child session's
  `customTools` (with `"ast_grep"` in `tools`), so scouts and reviewers get the
  same read-only search.
- Plan mode blocks tools by name (`bash`, `edit`, `write`, `codemode`,
  `subagent`), so `ast_grep` stays available. Adding rewriting later must use a
  separate tool name, otherwise plan mode would block search too.

## Residual risks

- The tool runs in the Pi process, which is not sandboxed (like `read`/`grep`).
  It can read anything the user can read; it never writes, because no rewrite
  flag is emitted.
- `ast-grep` is resolved through `PATH`, so the binary is whatever the profile
  provides. A writable `PATH` entry could shadow it, but such an entry already
  implies control of the account. Note that this is why the tool cannot rely on
  a nono command policy: none exists for `ast-grep`.
- Resource use is bounded: 30 s timeout with `SIGKILL`, `limit` (≤500) match cap
  with early stream termination, 20 lines and 500 characters per match, and
  `truncateHead` byte/line caps. Only the direct child is killed; ast-grep spawns
  no children of its own.

## Tests

```sh
cd home-manager/pi/extensions/ast-grep
PI_TEST_PACKAGE_DIR=<pi package dir> \
  node --test --import ./tests/register.mjs "tests/*.test.ts"
```

`args.test.ts` and `format.test.ts` are dependency-free. `integration.test.ts`
skips itself when `ast-grep` is not on `PATH` and otherwise covers search,
language inference, limits, no-match/exit-code mapping, `rule`, `debug`, and
cancellation.

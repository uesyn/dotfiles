# Read-only subagents

The `subagent` tool creates independent in-memory SDK sessions for code discovery,
planning, and review. Home Manager installs it alongside the read-only Git and
system-prompt-modifier extensions. The entire `extensions/` directory is one
Home Manager source tree: Pi canonicalizes entry-point symlinks, so distributing
siblings as separate store directories breaks their relative imports.

```text
subagent({
  tasks: [
    { agent: "scout", task: "Find how settings are loaded; cite paths and lines." },
    { agent: "reviewer", task: "Review the current diff for regressions." }
  ]
})
```

- Fixed roles: `scout`, `planner`, `reviewer`. No project-defined agents.
- 1–8 tasks per invocation; FIFO queue shared across invocations in the parent
  extension runtime, five running tasks, at most 32 running/queued tasks.
- Model and thinking level are captured when invoked. Physical models only;
  virtual models fail explicitly, without fallback.
- A native-provider bridge delegates requests to the parent's public model
  registry. It preserves dynamic providers, request-time authentication, and
  OAuth refresh without extracting the private runtime or copying credentials.
  Parent extension request hooks are not inherited.
- Children have only `read`, `grep`, `find`, `ls`, and the same read-only `git`
  and `ast_grep` tools as the parent. They never load global/project extension
  code, MCP, codemode, prompt templates, skills, or project settings. They load
  normal global/ancestor `AGENTS.md` context and the existing per-model prompt
  modifier.
- No parent conversation history. Supply relevant background in each task.
- No worktrees, edits, commits, shell commands, test execution, or recursive
  delegation. Parent owns implementation and verification.
- Results stay in input order. Each task independently reports completion,
  failure, cancellation, timeout, or turn-limit exhaustion, with usage. Nested
  model usage is returned to Pi for inclusion in the parent's session totals.
- Limits: five minutes from starting a queued task, 20 assistant responses.
  Compaction, automatic recovery retries, and cache warming are disabled.
- Parent cancellation, plan-mode activation, branch changes, and session
  shutdown cancel outstanding work. The tool is unavailable in plan mode and
  cannot be called indirectly from codemode (`model-only` exposure). Every
  provider request also checks the task signal and combines it with the SDK
  request signal, including cancellation during SDK prompt preflight.
- Answers are capped at 4 KiB/180 lines per task. Longer final/partial answers
  are saved to private temporary files; their paths appear in the results.
  Child transcripts are not persisted. Temporary answer files can contain
  sensitive project information; remove them when no longer needed.

## Boundaries

This is tool-level read-only delegation, not OS isolation. Sessions share the
parent process, filesystem permissions, and working tree. Avoid modifying files
under investigation until tasks finish. Repository text is untrusted input;
tool allowlists, not prompts, prevent requesting modification tools.

Cancellation is cooperative. A running task retains its scheduler slot until
its SDK/provider actually settles; the implementation does not pretend an
uncooperative provider stopped merely because a timer elapsed. Session shutdown
also waits for outstanding work. Hard kill guarantees require subprocesses.

This first version has no persistent task registry, resume, background jobs,
agent-specific model selection, or automatic integration.

## Tests

Requires Node.js 24 (for the test import resolver) and the installed Pi package,
not downloaded replacements. Pi itself supplies the extension's peer modules.

```sh
PI_TEST_PACKAGE_DIR=/path/to/pi-package \
  node --test --import ./home-manager/pi/extensions/tests/register.mjs \
  home-manager/pi/extensions/subagent/tests/*.test.ts
```

The package directory contains Pi's `package.json`, `dist/`, and `node_modules/`.
The resolver maps only Pi-provided peer imports; it does not modify repository
dependencies. Tests use mock providers and no external model API.

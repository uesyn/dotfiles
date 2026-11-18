# Read-only GitHub tool

`gh` exposes `repo_view`, `pr_list`, `pr_view`, `issue_list`, and `issue_view` as one discriminated-union schema. Supply `repo` as `owner/name`; view operations require `number`, while list operations accept only `state` and `limit` (maximum 100). Fields that belong to other operations are not included in the generated tool schema.

The tool runs fixed `gh` subcommands without a shell or arbitrary flags. The Nix-managed `gh` executable's absolute path is baked into the extension at build time; it is not resolved through `PATH`. An unconfigured path fails closed. It delegates authentication to gh. Set `GH_HOST` in Pi's environment before starting Pi to select GitHub Enterprise; otherwise the host is `github.com`. The model cannot choose the host. Authenticate with gh first. No automatic repository or host discovery is performed.

This constrains calls made through this tool, not the permissions of the underlying token or other tools. Pi runs outside nono, so this spawn has no sandbox backstop: the fixed argv is the whole enforcement boundary, and it is stricter than what `bash gh ...` may do. Responses are untrusted input (PR and issue `body`/`title` are attacker-controlled) and can contain prompt injection or private data; output is capped at 128 KiB per stream and is recorded in the Pi session. `--json` output JSON-escapes control characters, so terminal escape sequences from GitHub content reach the model only as `\u001b` text. GitHub and gh can have incidental effects such as audit logs.

Tests: set `PI_TEST_PACKAGE_DIR` to the installed Pi package directory, then run `node --test --import ./home-manager/pi/extensions/ast-grep/tests/register.mjs home-manager/pi/extensions/gh-readonly/tests/tool.test.ts` from the repository root.

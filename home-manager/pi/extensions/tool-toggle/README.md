# Tool toggle

- `/tool` shows the current model-facing active state of available tools.
- `/tool <name>` toggles a tool; Tab completes names.
- Home Manager's `dotfiles.pi.toolToggle.disabledByDefault` is a list of exact tool names, defaulting to `[ "gh" ]`. Set it to `[]` to enable gh by default. The generated `~/.pi/agent/tool-toggle.json` has a `disabledByDefault` array. Missing configuration means an empty list; malformed configuration warns and falls back to an empty list.
- Other direct/model-only tools available at session start are enabled by default. Unknown configured names are allowed for late tools. Other tools registered later follow their registration defaults. Hidden tools cannot be toggled.
- Choices are in memory only; a new session, resume, or reload resets them to the configured defaults. Plan mode manages its own persisted snapshot, so tool changes are unavailable while plan mode is active. Disabled choices are reapplied after plan transitions and tree navigation, and before model requests.
- Explicitly disabled tools are also blocked at `tool_call`, including calls already requested or nested through other tools. This is not an OS sandbox: a tool may invoke external programs or access functionality without making a Pi tool call. Tools with `codemode` or `deferred` exposure can remain reachable through codemode even when not model-facing; the list reports model-facing activation, not reachability.

Test with `node --test home-manager/pi/extensions/tool-toggle/tests/*.test.ts`.

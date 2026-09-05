---
name: code-review-graph
description: Uses the local code-review graph for code review, change-impact analysis, architecture exploration, and finding relevant implementation or test files. Use for multi-file changes, pull-request review, debugging dependencies, and architecture questions.
---

# Code Review Graph

Use the code-review-graph MCP tools when reviewing changes or investigating relationships across multiple files.

## Workflow

1. Call `build_or_update_graph_tool` before relying on graph results. This initializes a missing graph and catches changes made before the MCP auto-watcher started.
2. Start exploration with `get_minimal_context_tool`.
3. For working-tree or branch changes, call `detect_changes_tool`.
4. Use `get_impact_radius_tool` to identify callers, dependents, and tests.
5. Use `get_review_context_tool` before reading many files manually.
6. Use `query_graph_tool` for callers, callees, imports, inheritance, and tests.
7. Use `semantic_search_nodes_tool` only when identifier-based graph queries are insufficient.
8. Verify important conclusions by reading the referenced source files.

The MCP server runs an auto-watcher after its first use, so later file changes in the Pi session should be indexed incrementally. Run `build_or_update_graph_tool` again after rebases, bulk changes, or whenever the graph may be stale.

Do not treat graph output as authoritative. Fall back to `rg`, `git diff`, and direct source reads when the graph is missing, stale, or incomplete. For trivial single-file changes, direct source inspection may be cheaper than querying the graph.

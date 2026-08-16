/**
 * Configuration loading.
 *
 * Sources (project overrides global, both optional):
 * - ~/.pi/agent/undo.json        (global)
 * - <cwd>/.pi/undo.json          (project, CONFIG_DIR_NAME aware)
 */

import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { CONFIG_DIR_NAME } from "@earendil-works/pi-coding-agent";
import { DEFAULT_CONFIG } from "./types.ts";
import type { Config } from "./types.ts";
import { getAgentDir } from "./store.ts";

/** Pick only known keys with compatible types from a raw JSON object. */
function sanitize(value: unknown): Partial<Config> {
  if (typeof value !== "object" || value === null) return {};
  const raw = value as Record<string, unknown>;
  const out: Partial<Config> = {};

  if (typeof raw.autoCheckpoint === "boolean") out.autoCheckpoint = raw.autoCheckpoint;
  if (typeof raw.maxCheckpoints === "number" && raw.maxCheckpoints >= 2) {
    out.maxCheckpoints = Math.floor(raw.maxCheckpoints);
  }
  if (typeof raw.confirmBeforeRestore === "boolean") {
    out.confirmBeforeRestore = raw.confirmBeforeRestore;
  }
  if (typeof raw.restorePromptToEditor === "boolean") {
    out.restorePromptToEditor = raw.restorePromptToEditor;
  }
  if (
    Array.isArray(raw.exclude) &&
    raw.exclude.every((item) => typeof item === "string")
  ) {
    out.exclude = raw.exclude;
  }
  if (typeof raw.maxFileSizeMB === "number" && raw.maxFileSizeMB > 0) {
    out.maxFileSizeMB = raw.maxFileSizeMB;
  }
  if (typeof raw.stateDir === "string" && raw.stateDir.length > 0) {
    out.stateDir = raw.stateDir;
  }

  return out;
}

export async function loadConfig(cwd: string): Promise<Config> {
  const config: Config = { ...DEFAULT_CONFIG };
  const candidates = [
    join(getAgentDir(), "undo.json"),
    join(cwd, CONFIG_DIR_NAME, "undo.json"),
  ];
  for (const path of candidates) {
    try {
      const value: unknown = JSON.parse(await readFile(path, "utf8"));
      Object.assign(config, sanitize(value));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
        console.error(`pi-undo: failed to read ${path}:`, error);
      }
    }
  }
  return config;
}

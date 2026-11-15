import { access } from "node:fs/promises";
import { constants } from "node:fs";

// `shell` doubles as the readiness signal: null means no verified wrapper yet,
// so there is no separate "checking" state to observe.
export type State = {
  enabled: boolean;
  shell: string | null;
  error: string;
};

export function createState(): State {
  return { enabled: true, shell: null, error: "Sandbox has not been initialized" };
}

// Home Manager bakes the wrapper path into `endpoint.ts`, so there is no config
// to read; the only runtime failure is a wrapper that a store GC removed.
export async function initialize(state: State, shell: string): Promise<void> {
  state.enabled = true;
  state.shell = null;
  state.error = "Checking the sandbox wrapper";
  try {
    await access(shell, constants.X_OK);
    state.shell = shell;
  } catch {
    state.error = `Sandbox wrapper is missing or not executable: ${shell}`;
  }
}

export function status(state: State): string {
  if (!state.enabled) return "Sandbox OFF";
  return state.shell ? "Sandbox ON" : "Sandbox ERROR";
}

// Fail closed: an enabled sandbox never falls back to a local shell.
export function sandboxShell(state: State): string {
  if (!state.shell) throw new Error(`Sandbox is ON but unavailable: ${state.error}`);
  return state.shell;
}

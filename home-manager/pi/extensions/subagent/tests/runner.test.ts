import assert from "node:assert/strict";
import { test } from "node:test";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { AgentSessionEvent } from "@earendil-works/pi-coding-agent";
import { emptyUsage, runTask, type ChildSession, type ParentContext, type TaskResult } from "../runner.ts";

function result(): TaskResult {
  return { id: "test", agent: "scout", status: "queued", output: "", turns: 0, usage: emptyUsage() };
}

function message(stopReason: AssistantMessage["stopReason"] = "stop", text = "evidence"): AssistantMessage {
  const usage = emptyUsage();
  usage.input = 10;
  usage.output = 2;
  usage.totalTokens = 12;
  usage.cost.total = 0.1;
  return {
    role: "assistant", content: [{ type: "text", text }],
    api: "openai-completions", provider: "mock", model: "mock",
    stopReason, usage, timestamp: Date.now(),
  };
}

function child(run: (emit: (event: AgentSessionEvent) => void, stop: Promise<void>) => Promise<void>) {
  let listener: ((event: AgentSessionEvent) => void) | undefined;
  let stop!: () => void;
  const stopped = new Promise<void>((resolve) => { stop = resolve; });
  let disposed = false;
  let aborted = false;
  let unsubscribed = false;
  const session: ChildSession = {
    prompt: async (text, options) => {
      assert.match(text, /^Delegated task:/);
      assert.equal(options?.expandPromptTemplates, false);
      await run((event) => listener?.(event), stopped);
    },
    subscribe: (callback) => {
      listener = callback;
      return () => { listener = undefined; unsubscribed = true; };
    },
    abort: async () => { aborted = true; stop(); },
    dispose: () => { disposed = true; },
  };
  return { session, state: () => ({ disposed, aborted, unsubscribed }) };
}

const parent = {} as ParentContext;

test("completed answer joins text blocks and aggregates authoritative usage", async () => {
  const instance = child(async (emit) => {
    emit({ type: "message_end", message: message("toolUse", "working") });
    const final = message();
    final.content.push({ type: "text", text: "second block" });
    emit({ type: "message_end", message: final });
  });
  const output = result();
  await runTask(output, "/not-a-command", parent, new AbortController().signal, () => {}, {
    createSession: async () => instance.session,
  });
  assert.equal(output.status, "completed");
  assert.equal(output.output, "evidence\nsecond block");
  assert.equal(output.turns, 2);
  assert.equal(output.usage.input, 20);
  assert.equal(output.usage.cost.total, 0.2);
  assert.deepEqual(instance.state(), { disposed: true, aborted: false, unsubscribed: true });
});

test("LLM error and token-length responses are failures, preserving partial answers", async () => {
  for (const reason of ["error", "length", "toolUse"] as const) {
    const instance = child(async (emit) => {
      const value = message(reason);
      if (reason === "error") value.errorMessage = "provider refused";
      emit({ type: "message_end", message: value });
    });
    const output = result();
    await runTask(output, "task", parent, new AbortController().signal, () => {}, {
      createSession: async () => instance.session,
    });
    assert.equal(output.status, "failed");
    assert.match(output.output, /Partial answer:\nevidence/);
    if (reason === "error") assert.match(output.output, /provider refused/);
    assert.equal(instance.state().disposed, true);
  }
});

test("parent cancellation aborts, drains and disposes the child", async () => {
  const controller = new AbortController();
  const instance = child(async (emit, stopped) => {
    emit({ type: "message_end", message: message("toolUse", "partial") });
    controller.abort("parent cancelled");
    await stopped;
  });
  const output = result();
  await runTask(output, "task", parent, controller.signal, () => {}, {
    createSession: async () => instance.session,
  });
  assert.equal(output.status, "cancelled");
  assert.match(output.output, /partial/);
  assert.deepEqual(instance.state(), { disposed: true, aborted: true, unsubscribed: true });
});

test("timeout and turn limits cancel the SDK and never report success", async () => {
  for (const limit of ["time", "turns"]) {
    const instance = child(async (emit, stopped) => {
      if (limit === "turns") emit({ type: "message_end", message: message("toolUse") });
      await stopped;
    });
    const output = result();
    await runTask(output, "task", parent, new AbortController().signal, () => {}, {
      createSession: async () => instance.session,
      timeoutMs: limit === "time" ? 5 : 1000,
      maxTurns: 1,
    });
    assert.equal(output.status, limit === "time" ? "timed_out" : "turn_limit");
    assert.equal(instance.state().disposed, true);
    assert.equal(instance.state().aborted, true);
  }
});

test("first cancellation reason wins even if the timeout expires while draining", async () => {
  const controller = new AbortController();
  const instance = child(async (_emit, stopped) => {
    controller.abort("parent cancelled first");
    await stopped;
    await new Promise((resolve) => setTimeout(resolve, 15));
  });
  const output = result();
  await runTask(output, "task", parent, controller.signal, () => {}, {
    createSession: async () => instance.session,
    timeoutMs: 5,
  });
  assert.equal(output.status, "cancelled");
});

test("cancellation during session creation disposes the late-created session", async () => {
  const controller = new AbortController();
  let prompted = false;
  const instance = child(async () => { prompted = true; });
  const output = result();
  await runTask(output, "task", parent, controller.signal, () => {}, {
    createSession: async () => {
      controller.abort("during setup");
      return instance.session;
    },
  });
  assert.equal(output.status, "cancelled");
  assert.equal(prompted, false);
  assert.equal(instance.state().disposed, true);
  assert.equal(instance.state().aborted, true);
});

test("setup failures and empty answers fail without leaking a child", async () => {
  const setup = result();
  await runTask(setup, "task", parent, new AbortController().signal, () => {}, {
    createSession: async () => { throw new Error("bad setup"); },
  });
  assert.equal(setup.status, "failed");
  assert.match(setup.output, /bad setup/);
  const instance = child(async (emit) => emit({ type: "message_end", message: message("stop", "") }));
  const empty = result();
  await runTask(empty, "task", parent, new AbortController().signal, () => {}, {
    createSession: async () => instance.session,
  });
  assert.equal(empty.status, "failed");
  assert.match(empty.output, /empty answer/);
  assert.equal(instance.state().disposed, true);
});

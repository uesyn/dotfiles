import { test } from "node:test";
import assert from "node:assert/strict";
import toolToggle, { parseConfig } from "../index.ts";

function fixture(defaults: string[] = []) {
  let active = ["read", "bash"];
  const tools = [{ name: "read" }, { name: "bash" }, { name: "later" }, { name: "secret", exposure: "hidden" }];
  const messages: string[] = [];
  let plan = false;
  let idle = true;
  let command: any;
  const handlers: Record<string, any> = {};
  let planEvent: () => void = () => {};
  const pi = {
    getActiveTools: () => [...active],
    getAllTools: () => tools,
    setActiveTools: (names: string[]) => { active = names; },
    registerCommand: (_name: string, options: unknown) => { command = options; },
    on: (event: string, handler: unknown) => { handlers[event] = handler; },
    events: { on: (_event: string, handler: () => void) => { planEvent = handler; return () => {}; } },
  };
  const ctx = {
    isIdle: () => idle,
    sessionManager: { getBranch: () => plan ? [{ type: "custom", customType: "plan-mode", data: { enabled: true } }] : [] },
    ui: { notify: (message: string) => messages.push(message) },
  };
  toolToggle(pi as never, async () => defaults);
  return { command, onCall: handlers.tool_call, handlers, ctx, messages, active: () => active, setActive: (v: string[]) => { active = v; }, planEvent: () => planEvent(), plan: (v: boolean) => { plan = v; }, idle: (v: boolean) => { idle = v; } };
}

test("configured defaults reset at startup and can be overridden for the session", async () => {
  const f = fixture(["bash", "late-tool"]);
  await f.handlers.session_start({}, f.ctx);
  assert.ok(!f.active().includes("bash"));
  assert.equal((await f.onCall({ toolName: "late-tool" })).block, true);
  await f.command.handler("", f.ctx);
  assert.match(f.messages.pop()!, /disabled: bash/);
  await f.command.handler("bash", f.ctx);
  assert.ok(f.active().includes("bash"));
  assert.equal(await f.onCall({ toolName: "bash" }), undefined);
  await f.handlers.session_start({}, f.ctx);
  assert.ok(!f.active().includes("bash"));
  assert.equal((await f.onCall({ toolName: "bash" })).block, true);
});

test("reconciles late tools and plan mode restoration", async () => {
  const f = fixture(["bash"]);
  f.plan(true);
  await f.handlers.session_start({}, f.ctx);
  assert.deepEqual(f.active(), ["read"]);
  f.setActive(["read", "bash"]);
  f.planEvent();
  assert.deepEqual(f.active(), ["read"]);
  f.setActive(["read", "bash"]);
  await f.handlers.session_tree({}, f.ctx);
  assert.deepEqual(f.active(), ["read"]);
  f.setActive(["read", "bash"]);
  await f.handlers.before_agent_start({}, f.ctx);
  assert.deepEqual(f.active(), ["read"]);
});

test("validates configuration", () => {
  assert.deepEqual(parseConfig('{"disabledByDefault":["gh"]}'), ["gh"]);
  for (const value of ["{}", "null", '{"disabledByDefault":[1]}', '{"disabledByDefault":[""]}', "not json"]) {
    assert.throws(() => parseConfig(value));
  }
});

test("lists and toggles tools, including nested calls", async () => {
  const f = fixture();
  await f.command.handler("", f.ctx);
  assert.match(f.messages.pop()!, /enabled: read/);
  await f.command.handler("read", f.ctx);
  assert.deepEqual(f.active(), ["bash"]);
  assert.equal((await f.onCall({ toolName: "read" })).block, true);
  await f.command.handler("read", f.ctx);
  assert.deepEqual(f.active(), ["bash", "read"]);
  assert.equal(await f.onCall({ toolName: "read" }), undefined);
  await f.command.handler("later", f.ctx);
  assert.ok(f.active().includes("later"));
});

test("rejects unknown, hidden, busy, and plan-mode changes", async () => {
  const f = fixture();
  await f.command.handler("secret", f.ctx);
  await f.command.handler("missing", f.ctx);
  f.plan(true);
  await f.command.handler("bash", f.ctx);
  f.plan(false);
  f.idle(false);
  await f.command.handler("bash", f.ctx);
  assert.deepEqual(f.active(), ["read", "bash"]);
  assert.equal(f.messages.length, 4);
  assert.deepEqual(f.command.getArgumentCompletions("r"), [{ value: "read", label: "read" }]);
});

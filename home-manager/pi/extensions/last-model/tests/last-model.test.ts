/**
 * Behaviour tests for the last-model extension.
 *
 * Run from this directory:
 *   PI_TEST_PACKAGE_DIR=<pi package dir> \
 *     node --test --import ./tests/register.mjs "tests/*.test.ts"
 *
 * The extension is driven through a fake Pi API. Pi itself emits
 * `model_select`/`thinking_level_select` from `setModel`/`setThinkingLevel`, so
 * the fake does the same and the handlers see what they would in a session.
 */

import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import lastModel from "../index.ts";

type Handlers = Record<string, ((event: unknown, ctx: unknown) => unknown)[]>;

type FakeModel = { provider: string; id: string };

type FakePi = {
  on: (name: string, handler: (event: unknown, ctx: unknown) => unknown) => void;
  getThinkingLevel: () => string;
  setThinkingLevel: (level: string) => void;
  setModel: (model: FakeModel) => Promise<boolean>;
};

type FakeSession = {
  handlers: Handlers;
  notes: string[];
  model: FakeModel | undefined;
  level: string;
  pi: FakePi;
  ctx: {
    mode: "tui" | "rpc" | "print";
    model: FakeModel | undefined;
    modelRegistry: { find: (provider: string, id: string) => FakeModel | undefined };
    ui: { notify: (message: string, level: string) => void };
  };
};

/** The fake registry holds `registry`; anything else counts as unconfigured. */
function createSession(
  options: {
    model?: FakeModel;
    level?: string;
    registry?: FakeModel[];
    canAuthenticate?: boolean;
    /** `tui` unless a host or a script drives the session. */
    mode?: "tui" | "rpc" | "print";
  } = {},
): FakeSession {
  const notes: string[] = [];
  const handlers: Handlers = {};
  const registry = options.registry ?? [
    { provider: "prov", id: "alpha" },
    { provider: "prov", id: "beta" },
  ];

  const session = {
    handlers,
    notes,
    model: options.model,
    level: options.level ?? "off",
  } as FakeSession;

  session.ctx = {
    mode: options.mode ?? "tui",
    get model() {
      return session.model;
    },
    modelRegistry: {
      find: (provider, id) =>
        registry.find((model) => model.provider === provider && model.id === id),
    },
    ui: { notify: (message, level) => notes.push(`${level}: ${message}`) },
  };

  const emit = (name: string, event: unknown): void => {
    for (const handler of handlers[name] ?? []) void handler(event, session.ctx);
  };

  session.pi = {
    on: (name, handler) => {
      (handlers[name] ??= []).push(handler);
    },
    getThinkingLevel: () => session.level,
    setThinkingLevel: (level) => {
      if (level === session.level) return;
      const previousLevel = session.level;
      session.level = level;
      emit("thinking_level_select", { level, previousLevel });
    },
    setModel: async (model) => {
      if (options.canAuthenticate === false) return false;
      const previousModel = session.model;
      session.model = model;
      emit("model_select", { model, previousModel, source: "set" });
      return true;
    },
  };

  lastModel(session.pi as unknown as ExtensionAPI);
  return session;
}

async function emitSessionStart(session: FakeSession, reason: string): Promise<void> {
  for (const handler of session.handlers["session_start"] ?? []) {
    await handler({ reason }, session.ctx);
  }
}

async function emitModelSelect(session: FakeSession, model: FakeModel): Promise<void> {
  const previousModel = session.model;
  session.model = model;
  for (const handler of session.handlers["model_select"] ?? []) {
    await handler({ model, previousModel, source: "set" }, session.ctx);
  }
}

/** Wait for the queued atomic write to land. */
async function flushWrites(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 50));
}

async function withStateFile(run: (path: string) => Promise<void>): Promise<void> {
  const dir = await mkdtemp(join(tmpdir(), "pi-last-model-"));
  const path = join(dir, "last-model.json");
  // The path helper prefers the override, so no agent directory is read or written.
  process.env.PI_LAST_MODEL_FILE = path;
  try {
    await run(path);
  } finally {
    delete process.env.PI_LAST_MODEL_FILE;
    await rm(dir, { recursive: true, force: true });
  }
}

test("records the model and thinking level on every change", async () => {
  await withStateFile(async (path) => {
    const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "low" });

    await emitModelSelect(session, { provider: "prov", id: "beta" });
    await flushWrites();
    assert.deepEqual(JSON.parse(await readFile(path, "utf8")), {
      provider: "prov",
      model: "beta",
      thinkingLevel: "low",
    });

    session.pi.setThinkingLevel("xhigh");
    await flushWrites();
    assert.deepEqual(JSON.parse(await readFile(path, "utf8")), {
      provider: "prov",
      model: "beta",
      thinkingLevel: "xhigh",
    });
  });
});

test("a fresh session starts with the recorded model and level", async () => {
  await withStateFile(async (path) => {
    await writeFile(
      path,
      JSON.stringify({ provider: "prov", model: "beta", thinkingLevel: "high" }),
    );

    for (const reason of ["startup", "new"]) {
      const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "off" });
      await emitSessionStart(session, reason);
      assert.deepEqual(session.model, { provider: "prov", id: "beta" }, reason);
      assert.equal(session.level, "high", reason);
    }
  });
});

test("a session that carries its own model keeps it", async () => {
  await withStateFile(async (path) => {
    const record = { provider: "prov", model: "beta", thinkingLevel: "high" };
    await writeFile(path, JSON.stringify(record));

    for (const reason of ["resume", "fork", "reload"]) {
      const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "off" });
      await emitSessionStart(session, reason);
      assert.deepEqual(session.model, { provider: "prov", id: "alpha" }, reason);
      assert.equal(session.level, "off", reason);
      await flushWrites();
      assert.deepEqual(JSON.parse(await readFile(path, "utf8")), record, reason);
    }
  });
});

test("a host or scripted session neither reads nor writes the record", async () => {
  await withStateFile(async (path) => {
    const record = { provider: "prov", model: "beta", thinkingLevel: "high" };
    await writeFile(path, JSON.stringify(record));
    const before = await readFile(path, "utf8");

    // pi-web picks a new chat's model from its own picker and applies it right
    // after extensions bind, so taking the chat over reverts the selection; it
    // keeps each chat's model where it always did, in the session file.
    for (const mode of ["rpc", "print"] as const) {
      const session = createSession({
        model: { provider: "prov", id: "alpha" },
        level: "low",
        mode,
      });
      await emitSessionStart(session, "startup");
      assert.deepEqual(session.model, { provider: "prov", id: "alpha" }, mode);
      assert.equal(session.level, "low", mode);

      await emitModelSelect(session, { provider: "prov", id: "beta" });
      await flushWrites();
      assert.equal(await readFile(path, "utf8"), before, mode);
    }
  });
});

test("a fresh session with no record adopts the model it resolved", async () => {
  await withStateFile(async (path) => {
    const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "low" });
    await emitSessionStart(session, "startup");
    await flushWrites();
    assert.deepEqual(JSON.parse(await readFile(path, "utf8")), {
      provider: "prov",
      model: "alpha",
      thinkingLevel: "low",
    });
  });
});

test("a model chosen on the command line wins over the record", async () => {
  await withStateFile(async (path) => {
    await writeFile(
      path,
      JSON.stringify({ provider: "prov", model: "beta", thinkingLevel: "high" }),
    );

    const pinnedInvocations = [
      ["--model", "prov/alpha"],
      ["--model=prov/alpha"],
      ["--thinking", "low"],
      ["--models", "prov/*"],
    ];
    for (const args of pinnedInvocations) {
      const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "low" });
      const argv = process.argv;
      process.argv = [...argv.slice(0, 2), ...args];
      try {
        await emitSessionStart(session, "startup");
      } finally {
        process.argv = argv;
      }
      assert.deepEqual(session.model, { provider: "prov", id: "alpha" }, args.join(" "));
      assert.equal(session.level, "low", args.join(" "));
    }
  });
});

test("applying the record writes nothing back", async () => {
  await withStateFile(async (path) => {
    await writeFile(
      path,
      JSON.stringify({ provider: "prov", model: "beta", thinkingLevel: "max" }),
    );
    const before = await readFile(path, "utf8");

    const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "off" });
    await emitSessionStart(session, "startup");
    await flushWrites();
    assert.equal(await readFile(path, "utf8"), before);
  });
});

test("unchanged selections do not rewrite the file", async () => {
  await withStateFile(async (path) => {
    const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "low" });
    await emitModelSelect(session, { provider: "prov", id: "beta" });
    await flushWrites();
    const { mtimeMs } = await stat(path);

    await emitModelSelect(session, { provider: "prov", id: "beta" });
    await flushWrites();
    assert.equal((await stat(path)).mtimeMs, mtimeMs);
  });
});

test("an unavailable model warns and keeps the record", async () => {
  await withStateFile(async (path) => {
    const record = { provider: "gone", model: "retired", thinkingLevel: "low" };
    await writeFile(path, JSON.stringify(record));

    const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "off" });
    await emitSessionStart(session, "startup");

    assert.match(session.notes.at(-1) ?? "", /^warning: Last model not found/);
    assert.deepEqual(JSON.parse(await readFile(path, "utf8")), record);
    assert.deepEqual(session.model, { provider: "prov", id: "alpha" });
  });
});

test("a model without credentials warns and is not used", async () => {
  await withStateFile(async (path) => {
    await writeFile(
      path,
      JSON.stringify({ provider: "prov", model: "beta", thinkingLevel: "low" }),
    );

    const session = createSession({
      model: { provider: "prov", id: "alpha" },
      level: "off",
      canAuthenticate: false,
    });
    await emitSessionStart(session, "startup");

    assert.match(session.notes.at(-1) ?? "", /^error: No API key for last model/);
    assert.deepEqual(session.model, { provider: "prov", id: "alpha" });
    assert.equal(session.level, "off");
  });
});

test("a malformed record is ignored", async () => {
  await withStateFile(async (path) => {
    for (const content of ["{}", "null", '{"provider":"prov"}', "not json"]) {
      await writeFile(path, content);
      const session = createSession({ model: { provider: "prov", id: "alpha" }, level: "off" });
      await emitSessionStart(session, "startup");
      assert.deepEqual(session.model, { provider: "prov", id: "alpha" }, content);
    }
  });
});

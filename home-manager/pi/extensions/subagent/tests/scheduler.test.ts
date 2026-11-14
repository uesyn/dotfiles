import assert from "node:assert/strict";
import { test } from "node:test";
import { Scheduler } from "../scheduler.ts";

function gate() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => { resolve = done; });
  return { promise, resolve };
}

test("one FIFO limit covers independent batches; results keep their own order", async () => {
  const scheduler = new Scheduler(2);
  const gates = Array.from({ length: 5 }, gate);
  const starts: number[] = [];
  let active = 0;
  let peak = 0;
  const jobs = gates.map((item, index) => scheduler.run(async () => {
    starts.push(index);
    peak = Math.max(peak, ++active);
    await item.promise;
    active--;
    return index;
  }, new AbortController().signal));
  assert.deepEqual(starts, [0, 1]);
  gates[1].resolve();
  assert.equal(await jobs[1], 1);
  assert.deepEqual(starts, [0, 1, 2]);
  gates[0].resolve();
  await jobs[0];
  assert.deepEqual(starts, [0, 1, 2, 3]);
  gates[2].resolve();
  await jobs[2];
  gates[3].resolve();
  gates[4].resolve();
  assert.deepEqual(await Promise.all(jobs), [0, 1, 2, 3, 4]);
  assert.equal(peak, 2);
});

test("queued cancellation never starts the job; running cancellation retains its slot", async () => {
  const scheduler = new Scheduler(1);
  const running = gate();
  const runningAbort = new AbortController();
  const first = scheduler.run(async () => running.promise, runningAbort.signal);
  const queuedAbort = new AbortController();
  let started = false;
  const queued = scheduler.run(async () => { started = true; }, queuedAbort.signal);
  const rejected = assert.rejects(queued, { message: "cancel queued" });
  queuedAbort.abort(new Error("cancel queued"));
  await rejected;
  runningAbort.abort();
  const next = scheduler.run(async () => { started = true; }, new AbortController().signal);
  await Promise.resolve();
  assert.equal(started, false);
  running.resolve();
  await first;
  await next;
  assert.equal(started, true);
});

test("failure releases a slot and queue capacity is bounded", async () => {
  const scheduler = new Scheduler(1, 1);
  const block = gate();
  const first = scheduler.run(async () => {
    await block.promise;
    throw new Error("child failed");
  }, new AbortController().signal);
  await assert.rejects(scheduler.run(async () => {}, new AbortController().signal), /queue is full/);
  const rejected = assert.rejects(first, /child failed/);
  block.resolve();
  await rejected;
  assert.equal(await scheduler.run(async () => 42, new AbortController().signal), 42);
});

test("already cancelled jobs are rejected without starting", async () => {
  let started = false;
  const signal = AbortSignal.abort(new Error("cancelled"));
  await assert.rejects(new Scheduler().run(async () => { started = true; }, signal), /cancelled/);
  assert.equal(started, false);
});

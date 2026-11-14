type Entry = {
  start: () => void;
  cancel: () => void;
};

// One instance is shared by all tool invocations in an extension runtime.
// A cancelled running job retains its slot until it actually stops.
export class Scheduler {
  private active = 0;
  private queue: Entry[] = [];
  private readonly concurrency: number;
  private readonly capacity: number;

  constructor(concurrency = 2, capacity = 32) {
    if (!Number.isInteger(concurrency) || concurrency < 1 ||
      !Number.isInteger(capacity) || capacity < concurrency) {
      throw new Error("Invalid scheduler limits");
    }
    this.concurrency = concurrency;
    this.capacity = capacity;
  }

  run<T>(job: () => Promise<T>, signal: AbortSignal): Promise<T> {
    if (signal.aborted) return Promise.reject(signal.reason);
    if (this.active + this.queue.length >= this.capacity) {
      return Promise.reject(new Error("Subagent queue is full"));
    }

    return new Promise<T>((resolve, reject) => {
      const entry: Entry = {
        cancel: () => {
          this.queue = this.queue.filter((item) => item !== entry);
          signal.removeEventListener("abort", entry.cancel);
          reject(signal.reason);
        },
        start: () => {
          signal.removeEventListener("abort", entry.cancel);
          this.active++;
          void (async () => {
            try {
              signal.throwIfAborted();
              resolve(await job());
            } catch (error) {
              reject(error);
            } finally {
              this.active--;
              this.drain();
            }
          })();
        },
      };

      signal.addEventListener("abort", entry.cancel, { once: true });
      this.queue.push(entry);
      this.drain();
    });
  }

  private drain(): void {
    while (this.active < this.concurrency && this.queue.length > 0) {
      this.queue.shift()!.start();
    }
  }
}

import type { SessionEntry } from "@earendil-works/pi-coding-agent";
import { describe, expect, it } from "bun:test";
import { rebuildFromSession } from "../history.ts";
import {
  CHECKPOINT_VERSION,
  CUSTOM_TYPE,
  LEGACY_CLEAR_TYPE,
  PURGE_TYPE,
  REDO_TYPE,
  createState,
} from "../types.ts";

function checkpoint(id: string, index: number) {
  return {
    id,
    type: "custom",
    customType: CUSTOM_TYPE,
    data: {
      v: CHECKPOINT_VERSION,
      index,
      anchorId: null,
      filesChanged: [],
      timestamp: index,
      treeHash: `${index}`.repeat(40),
    },
  };
}

describe("checkpoint history", () => {
  it("discards checkpoints and redo markers preceding an undo-purge marker", () => {
    const old = checkpoint("old", 0);
    const fresh = checkpoint("fresh", 0);
    const entries = [
      old,
      { id: "redo-old", type: "custom", customType: REDO_TYPE, data: { redo: ["old"] } },
      { id: "purge", type: "custom", customType: PURGE_TYPE, data: {} },
      fresh,
      { id: "redo-fresh", type: "custom", customType: REDO_TYPE, data: { redo: ["fresh"] } },
    ];
    const byId = new Map(entries.map((entry) => [entry.id, entry]));
    const state = createState();

    rebuildFromSession(
      {
        getBranch: () => entries as unknown as SessionEntry[],
        getEntry: (id) => byId.get(id) as unknown as SessionEntry | undefined,
      },
      state,
    );

    expect(state.checkpoints.map((meta) => meta.entryId)).toEqual(["fresh"]);
    expect(state.redoStack.map((meta) => meta.entryId)).toEqual(["fresh"]);
  });

  it("recognizes the legacy snapshot-removal marker", () => {
    const old = checkpoint("old", 0);
    const fresh = checkpoint("fresh", 0);
    const entries = [
      old,
      { id: "legacy", type: "custom", customType: LEGACY_CLEAR_TYPE, data: {} },
      fresh,
    ];
    const byId = new Map(entries.map((entry) => [entry.id, entry]));
    const state = createState();

    rebuildFromSession(
      {
        getBranch: () => entries as unknown as SessionEntry[],
        getEntry: (id) => byId.get(id) as unknown as SessionEntry | undefined,
      },
      state,
    );

    expect(state.checkpoints.map((meta) => meta.entryId)).toEqual(["fresh"]);
    expect(state.redoStack).toEqual([]);
  });
});

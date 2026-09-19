/**
 * favorite-models — favorite model presets with per-favorite variables.
 *
 * Commands:
 *   /favorite                pick a favorite and apply it
 *   /favorite add [key]      add a favorite from the available models
 *   /favorite remove [key]   remove a favorite
 *   /favorite list           list favorites
 *
 * A favorite is a model plus its variable: the thinking level applied when
 * the favorite is selected. The same model can be saved several times with
 * different thinking levels, each as its own favorite. Favorites live in
 * `<agentDir>/favorite-models.json` (override with PI_FAVORITE_MODELS_FILE),
 * which keeps them writable even when settings.json is managed read-only
 * (e.g. by home-manager).
 */

import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import type { Api, Model } from "@earendil-works/pi-ai";
import {
  getAgentDir,
  DynamicBorder,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  type AutocompleteItem,
  Container,
  fuzzyFilter,
  Input,
  Spacer,
  Text,
  type SelectItem,
} from "@earendil-works/pi-tui";

/** Thinking levels pi supports, in canonical order. */
const THINKING_LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
] as const;
type ThinkingLevel = (typeof THINKING_LEVELS)[number];

const THINKING_LEVEL_SET: ReadonlySet<string> = new Set(THINKING_LEVELS);

/** A favorite model and its per-favorite variables. */
type FavoriteModel = {
  provider: string;
  model: string;
  /**
   * Variable applied when the favorite is selected. Only the thinking level is
   * supported today; unknown fields in the file are ignored so the format can
   * grow without breaking older versions.
   */
  thinkingLevel?: ThinkingLevel;
};

/** Result of resolving a user-supplied favorite key. */
type FavoriteMatch = { favorite: FavoriteModel } | { ambiguous: FavoriteModel[] };

const SUBCOMMAND_COMPLETIONS: AutocompleteItem[] = [
  { value: "add", label: "add", description: "Add a favorite model (level is part of its identity)" },
  { value: "remove", label: "remove", description: "Remove a favorite model" },
  { value: "list", label: "list", description: "List favorite models" },
];

const REMOVE_SUBCOMMANDS: ReadonlySet<string> = new Set(["remove", "rm", "delete"]);

function favoritesPath(): string {
  return (
    process.env.PI_FAVORITE_MODELS_FILE?.trim() ||
    join(getAgentDir(), "favorite-models.json")
  );
}

function favoriteKey(favorite: FavoriteModel): string {
  const level = favorite.thinkingLevel ? `:${favorite.thinkingLevel}` : "";
  return `${favoriteModelKey(favorite)}${level}`;
}

/** Key of a favorite's model, ignoring the thinking level. */
function favoriteModelKey(favorite: Pick<FavoriteModel, "provider" | "model">): string {
  return `${favorite.provider}/${favorite.model}`;
}

function modelKey(model: Pick<Model<Api>, "provider" | "id">): string {
  return `${model.provider}/${model.id}`;
}

function isThinkingLevel(value: unknown): value is ThinkingLevel {
  return typeof value === "string" && THINKING_LEVEL_SET.has(value);
}

/** Keep only well-formed entries; identical duplicates keep their first position. */
function sanitizeFavorites(value: unknown): FavoriteModel[] {
  const record = (typeof value === "object" && value !== null ? value : {}) as Record<
    string,
    unknown
  >;
  const rawFavorites = Array.isArray(value)
    ? value
    : Array.isArray(record.favorites)
      ? record.favorites
      : [];

  const favorites = new Map<string, FavoriteModel>();
  for (const entry of rawFavorites) {
    if (typeof entry !== "object" || entry === null) continue;
    const raw = entry as Record<string, unknown>;
    if (typeof raw.provider !== "string" || raw.provider.length === 0) continue;
    if (typeof raw.model !== "string" || raw.model.length === 0) continue;

    const favorite: FavoriteModel = { provider: raw.provider, model: raw.model };
    if (isThinkingLevel(raw.thinkingLevel)) favorite.thinkingLevel = raw.thinkingLevel;
    favorites.set(favoriteKey(favorite), favorite);
  }

  return [...favorites.values()];
}

let writeQueue: Promise<void> = Promise.resolve();

function saveFavorites(favorites: FavoriteModel[]): Promise<void> {
  const path = favoritesPath();

  writeQueue = writeQueue
    .then(async () => {
      const temporaryPath = `${path}.${process.pid}.tmp`;
      await mkdir(dirname(path), { recursive: true });
      await writeFile(temporaryPath, `${JSON.stringify({ favorites }, null, 2)}\n`, {
        encoding: "utf8",
        mode: 0o600,
      });
      await rename(temporaryPath, path);
    })
    .catch((error) => {
      console.error(`favorite-models: failed to write ${path}:`, error);
    });

  return writeQueue;
}

async function loadFavorites(): Promise<FavoriteModel[]> {
  const path = favoritesPath();

  try {
    const value: unknown = JSON.parse(await readFile(path, "utf8"));
    return sanitizeFavorites(value);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      console.error(`favorite-models: failed to read ${path}:`, error);
    }
    return [];
  }
}

function describeModel(model: Pick<Model<Api>, "provider" | "id" | "name">): string {
  const name = model.name && model.name !== model.id ? ` (${model.name})` : "";
  return `${model.provider}/${model.id}${name}`;
}

function describeFavorite(favorite: FavoriteModel): string {
  const level = favorite.thinkingLevel ? ` (thinking: ${favorite.thinkingLevel})` : "";
  return `${favoriteModelKey(favorite)}${level}`;
}

const MAX_VISIBLE_ITEMS = 12;

/**
 * Searchable single-select picker (fuzzy match over label and description,
 * like the built-in /model picker). Falls back to the plain selector outside
 * the TUI, where custom components are unavailable (e.g. RPC mode).
 */
async function pickItem(
  ctx: ExtensionContext,
  title: string,
  items: SelectItem[],
): Promise<string | undefined> {
  if (items.length === 0) return undefined;

  if (ctx.mode !== "tui") {
    const labels = items.map((item) =>
      item.description ? `${item.label}  ${item.description}` : item.label,
    );
    const choice = await ctx.ui.select(title, labels);
    if (choice === undefined) return undefined;
    return items[labels.indexOf(choice)]?.value;
  }

  return ctx.ui.custom<string | undefined>((tui, theme, keybindings, done) => {
    const container = new Container();
    const search = new Input();
    const list = new Text("", 0, 0);
    let filtered = items;
    let selectedIndex = 0;

    const rerender = (): void => {
      if (filtered.length === 0) {
        list.setText(theme.fg("muted", "  No matches"));
        tui.requestRender();
        return;
      }

      const start = Math.max(
        0,
        Math.min(
          selectedIndex - Math.floor(MAX_VISIBLE_ITEMS / 2),
          filtered.length - MAX_VISIBLE_ITEMS,
        ),
      );
      const end = Math.min(start + MAX_VISIBLE_ITEMS, filtered.length);
      const lines: string[] = [];
      for (let index = start; index < end; index++) {
        const item = filtered[index];
        if (!item) continue;
        const isSelected = index === selectedIndex;
        const cursor = isSelected ? theme.fg("accent", "→ ") : "  ";
        const label = isSelected ? theme.fg("accent", item.label) : item.label;
        const description = item.description ? ` ${theme.fg("muted", item.description)}` : "";
        lines.push(`${cursor}${label}${description}`);
      }
      if (start > 0 || end < filtered.length) {
        lines.push(theme.fg("muted", `  (${selectedIndex + 1}/${filtered.length})`));
      }
      list.setText(lines.join("\n"));
      tui.requestRender();
    };

    const refilter = (): void => {
      const query = search.getValue().trim();
      filtered = query
        ? fuzzyFilter(items, query, (item) => `${item.label} ${item.description ?? ""}`)
        : items;
      selectedIndex = 0;
      rerender();
    };

    container.addChild(new DynamicBorder((text: string) => theme.fg("accent", text)));
    container.addChild(new Spacer(1));
    container.addChild(new Text(theme.fg("accent", theme.bold(title)), 0, 0));
    container.addChild(new Spacer(1));
    container.addChild(search);
    container.addChild(new Spacer(1));
    container.addChild(list);
    container.addChild(new Spacer(1));
    container.addChild(
      new Text(theme.fg("dim", "  ↑↓ navigate · type to filter · enter select · esc cancel"), 0, 0),
    );
    container.addChild(new DynamicBorder((text: string) => theme.fg("accent", text)));

    rerender();

    return {
      get focused(): boolean {
        return search.focused;
      },
      set focused(value: boolean) {
        search.focused = value;
      },
      render(width: number) {
        return container.render(width);
      },
      invalidate() {
        container.invalidate();
      },
      handleInput(data: string) {
        if (keybindings.matches(data, "tui.select.up")) {
          if (filtered.length > 0) {
            selectedIndex = (selectedIndex - 1 + filtered.length) % filtered.length;
            rerender();
          }
          return;
        }
        if (keybindings.matches(data, "tui.select.down")) {
          if (filtered.length > 0) {
            selectedIndex = (selectedIndex + 1) % filtered.length;
            rerender();
          }
          return;
        }
        if (keybindings.matches(data, "tui.select.confirm")) {
          const item = filtered[selectedIndex];
          if (item) done(item.value);
          return;
        }
        if (keybindings.matches(data, "tui.select.cancel")) {
          done(undefined);
          return;
        }
        search.handleInput(data);
        refilter();
      },
    };
  });
}

type PickThinkingLevelResult = { level?: ThinkingLevel } | undefined;

export default function favoriteModelsExtension(pi: ExtensionAPI): void {
  function requireUI(ctx: ExtensionContext, hint: string): boolean {
    if (ctx.hasUI) return true;
    ctx.ui.notify(hint, "warning");
    return false;
  }

  function matchFavorite(list: FavoriteModel[], key: string): FavoriteMatch | undefined {
    const needle = key.trim().toLowerCase();
    if (needle.length === 0) return undefined;

    // Full identity including the thinking level.
    const exact = list.find((favorite) => favoriteKey(favorite).toLowerCase() === needle);
    if (exact) return { favorite: exact };

    // provider/model without a level, only when unambiguous.
    const byModel = list.filter(
      (favorite) => favoriteModelKey(favorite).toLowerCase() === needle,
    );
    if (byModel.length === 1) return { favorite: byModel[0] };
    if (byModel.length > 1) return { ambiguous: byModel };

    // Bare model id (which may itself contain slashes), only when unambiguous.
    const byId = list.filter((favorite) => favorite.model.toLowerCase() === needle);
    if (byId.length === 1) return { favorite: byId[0] };
    if (byId.length > 1) return { ambiguous: byId };
    return undefined;
  }

  function resolveFavorite(
    ctx: ExtensionContext,
    list: FavoriteModel[],
    key: string,
  ): FavoriteModel | undefined {
    const match = matchFavorite(list, key);
    if (!match) {
      ctx.ui.notify(`Favorite not found: ${key}`, "warning");
      return undefined;
    }
    if ("ambiguous" in match) {
      const candidates = match.ambiguous.map(favoriteKey).join(", ");
      ctx.ui.notify(
        `Multiple favorites match ${key}: ${candidates}. Specify the thinking level.`,
        "warning",
      );
      return undefined;
    }
    return match.favorite;
  }

  function findAvailableModel(ctx: ExtensionContext, key: string): Model<Api> | undefined {
    const trimmed = key.trim();
    if (trimmed.length === 0) return undefined;

    const slash = trimmed.indexOf("/");
    if (slash > 0) {
      const model = ctx.modelRegistry.find(trimmed.slice(0, slash), trimmed.slice(slash + 1));
      if (model) return model;
    }

    const needle = trimmed.toLowerCase();
    const matches = ctx.modelRegistry
      .getAvailable()
      .filter(
        (model) =>
          model.id.toLowerCase() === needle ||
          model.name.toLowerCase() === needle ||
          modelKey(model).toLowerCase() === needle,
      );
    return matches.length === 1 ? matches[0] : undefined;
  }

  function isActiveFavorite(
    ctx: ExtensionContext,
    favorite: FavoriteModel,
    currentLevel: ThinkingLevel,
  ): boolean {
    const model = ctx.model;
    if (!model || model.provider !== favorite.provider || model.id !== favorite.model) {
      return false;
    }
    return favorite.thinkingLevel === undefined || favorite.thinkingLevel === currentLevel;
  }

  function favoriteItems(
    list: FavoriteModel[],
    description?: (favorite: FavoriteModel) => string | undefined,
  ): SelectItem[] {
    return list.map((favorite) => ({
      value: favoriteKey(favorite),
      label: describeFavorite(favorite),
      description: description?.(favorite),
    }));
  }

  async function pickModel(
    ctx: ExtensionContext,
    list: FavoriteModel[],
  ): Promise<Model<Api> | undefined> {
    const models = [...ctx.modelRegistry.getAvailable()];
    if (models.length === 0) {
      ctx.ui.notify("No available models. Configure a provider or /login first.", "warning");
      return undefined;
    }

    const current = ctx.model;
    const isCurrent = (model: Model<Api>): boolean =>
      current !== undefined && model.provider === current.provider && model.id === current.id;
    const known = new Set(list.map(favoriteModelKey));

    // Current model first, then provider/id so the list stays predictable.
    models.sort(
      (a, b) =>
        Number(isCurrent(b)) - Number(isCurrent(a)) ||
        a.provider.localeCompare(b.provider) ||
        a.id.localeCompare(b.id),
    );

    const items: SelectItem[] = models.map((model) => {
      const marks: string[] = [];
      if (isCurrent(model)) marks.push("● current");
      if (known.has(modelKey(model))) marks.push("★ favorite");
      return {
        value: modelKey(model),
        label: describeModel(model),
        description: marks.length > 0 ? marks.join(" ") : undefined,
      };
    });

    const selected = await pickItem(ctx, "Add favorite model", items);
    return selected === undefined
      ? undefined
      : models.find((model) => modelKey(model) === selected);
  }

  /**
   * Ask for the favorite's variable. Returns undefined on cancel, `{}` when the
   * model has no thinking variable to set.
   */
  async function pickThinkingLevel(
    ctx: ExtensionContext,
    model: Model<Api>,
  ): Promise<PickThinkingLevelResult> {
    if (!ctx.hasUI || !model.reasoning) return {};

    // null marks a level as unsupported by this model.
    const supported = THINKING_LEVELS.filter(
      (level) => model.thinkingLevelMap?.[level] !== null,
    );
    if (supported.length === 0) return {};

    const current = ctx.model;
    const preferred =
      current !== undefined && current.provider === model.provider && current.id === model.id
        ? pi.getThinkingLevel()
        : undefined;
    const levels = [
      ...(preferred && supported.includes(preferred) ? [preferred] : []),
      ...supported.filter((level) => level !== preferred),
    ];
    const labels = levels.map((level) => (level === preferred ? `${level} (current)` : level));

    const choice = await ctx.ui.select(`Thinking level for ${describeModel(model)}`, labels);
    if (choice === undefined) return undefined;
    return { level: levels[labels.indexOf(choice)] };
  }

  async function applyFavorite(ctx: ExtensionContext, favorite: FavoriteModel): Promise<void> {
    const key = favoriteKey(favorite);
    const model = ctx.modelRegistry.find(favorite.provider, favorite.model);
    if (!model) {
      ctx.ui.notify(`Favorite model not found in the registry: ${key}`, "warning");
      return;
    }

    if (!(await pi.setModel(model))) {
      ctx.ui.notify(`No API key for ${key}`, "error");
      return;
    }

    if (favorite.thinkingLevel) pi.setThinkingLevel(favorite.thinkingLevel);
    ctx.ui.notify(`Switched to favorite: ${describeFavorite(favorite)}`, "info");
  }

  async function selectFavorite(ctx: ExtensionContext, key?: string): Promise<void> {
    const list = await loadFavorites();
    if (list.length === 0) {
      ctx.ui.notify("No favorites yet. Add one with /favorite add.", "warning");
      return;
    }

    let favorite: FavoriteModel | undefined;
    if (key) {
      favorite = resolveFavorite(ctx, list, key);
      if (!favorite) return;
    } else {
      if (!requireUI(ctx, "Pass a favorite key: /favorite <provider/model>")) return;
      const currentLevel = pi.getThinkingLevel();
      const selected = await pickItem(
        ctx,
        "Select favorite model",
        favoriteItems(list, (entry) =>
          isActiveFavorite(ctx, entry, currentLevel) ? "● current" : undefined,
        ),
      );
      if (selected === undefined) return;
      favorite = list.find((entry) => favoriteKey(entry) === selected);
    }

    if (favorite) await applyFavorite(ctx, favorite);
  }

  async function addFavorite(ctx: ExtensionCommandContext, key?: string): Promise<void> {
    const list = await loadFavorites();

    let model: Model<Api> | undefined;
    if (key) {
      model = findAvailableModel(ctx, key);
      if (!model) {
        ctx.ui.notify(`Available model not found: ${key}`, "warning");
        return;
      }
    } else {
      if (!requireUI(ctx, "Pass a model key: /favorite add <provider/model>")) return;
      model = await pickModel(ctx, list);
      if (!model) return;
    }

    const picked = await pickThinkingLevel(ctx, model);
    if (!picked) return;

    const favorite: FavoriteModel = { provider: model.provider, model: model.id };
    if (picked.level) favorite.thinkingLevel = picked.level;

    // Full identity: the same model at another thinking level is a new favorite.
    if (list.some((entry) => favoriteKey(entry) === favoriteKey(favorite))) {
      ctx.ui.notify(`Already a favorite: ${describeFavorite(favorite)}`, "info");
      return;
    }

    list.push(favorite);
    await saveFavorites(list);
    ctx.ui.notify(`Added favorite: ${describeFavorite(favorite)}`, "info");
  }

  async function removeFavorite(ctx: ExtensionCommandContext, key?: string): Promise<void> {
    const list = await loadFavorites();
    if (list.length === 0) {
      ctx.ui.notify("No favorites yet. Add one with /favorite add.", "warning");
      return;
    }

    let index = -1;
    if (key) {
      const favorite = resolveFavorite(ctx, list, key);
      if (!favorite) return;
      index = list.indexOf(favorite);
      if (index < 0) {
        ctx.ui.notify(`Favorite not found: ${key}`, "warning");
        return;
      }
    } else {
      if (!requireUI(ctx, "Pass a favorite key: /favorite remove <provider/model>")) return;
      const selected = await pickItem(ctx, "Remove favorite model", favoriteItems(list));
      if (selected === undefined) return;
      index = list.findIndex((entry) => favoriteKey(entry) === selected);
    }

    const [removed] = list.splice(index, 1);
    await saveFavorites(list);
    if (removed) ctx.ui.notify(`Removed favorite: ${describeFavorite(removed)}`, "info");
  }

  async function listFavorites(ctx: ExtensionCommandContext): Promise<void> {
    const list = await loadFavorites();
    if (list.length === 0) {
      ctx.ui.notify("No favorites yet. Add one with /favorite add.", "info");
      return;
    }

    const lines = list.map(
      (favorite, index) => `${index + 1}. ${describeFavorite(favorite)}`,
    );
    ctx.ui.notify(`Favorite models:\n${lines.join("\n")}`, "info");
  }

  async function completeArgument(argumentText: string): Promise<AutocompleteItem[] | null> {
    const trimmed = argumentText.trimStart();
    const spaceIndex = trimmed.indexOf(" ");

    if (spaceIndex === -1) {
      const matches = SUBCOMMAND_COMPLETIONS.filter((item) =>
        item.value.startsWith(trimmed.toLowerCase()),
      );
      return matches.length > 0 ? matches : null;
    }

    const subcommand = trimmed.slice(0, spaceIndex).toLowerCase();
    if (!REMOVE_SUBCOMMANDS.has(subcommand)) return null;

    // Completion values replace the whole argument text, so keep the subcommand
    // the user typed (remove / rm / delete).
    const favorites = await loadFavorites();
    const matches = favorites
      .map((favorite) => `${subcommand} ${favoriteKey(favorite)}`)
      .filter((value) => value.toLowerCase().startsWith(trimmed.toLowerCase()))
      .map((value) => ({ value, label: value.slice(subcommand.length + 1) }));
    return matches.length > 0 ? matches : null;
  }

  pi.registerShortcut("ctrl+l", {
    description: "Select favorite model",
    handler: async (ctx) => {
      await selectFavorite(ctx);
    },
  });

  pi.registerCommand("favorite", {
    description: "Select, add, remove, and list favorite models",
    getArgumentCompletions: (argumentText) => completeArgument(argumentText),
    handler: async (args, ctx) => {
      const tokens = args
        .trim()
        .split(/\s+/)
        .filter((token) => token.length > 0);
      const subcommand = tokens[0]?.toLowerCase();
      const rest = tokens.slice(1).join(" ");

      switch (subcommand) {
        case undefined:
          await selectFavorite(ctx);
          return;
        case "add":
          await addFavorite(ctx, rest || undefined);
          return;
        case "remove":
        case "rm":
        case "delete":
          await removeFavorite(ctx, rest || undefined);
          return;
        case "list":
        case "ls":
          await listFavorites(ctx);
          return;
        default:
          await selectFavorite(ctx, tokens.join(" "));
          return;
      }
    },
  });
}

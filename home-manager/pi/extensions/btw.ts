import type { UserMessage } from "@earendil-works/pi-ai";
import {
  BorderedLoader,
  buildSessionContext,
  convertToLlm,
  DynamicBorder,
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { Container, Markdown, matchesKey, Text } from "@earendil-works/pi-tui";

const SIDE_QUESTION_PROMPT = `
You are answering a temporary side question about an ongoing conversation.

Use the conversation and system context provided to answer the question. This is
not part of the main conversation: do not mention this side exchange as if it
were a user message in the main thread. Do not call tools or make changes; use
only the supplied context. Be concise and answer the question directly.
`;

type QueryResult =
  | { kind: "answer"; text: string }
  | { kind: "cancelled" }
  | { kind: "error"; error: unknown };

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function extractText(response: {
  content: Array<{ type: string; text?: string }>;
}): string {
  return response.content
    .filter((content): content is { type: "text"; text: string } => content.type === "text" && typeof content.text === "string")
    .map((content) => content.text)
    .join("\n")
    .trim();
}

function buildMessages(ctx: ExtensionCommandContext, question: string) {
  const sessionContext = buildSessionContext(
    ctx.sessionManager.getEntries(),
    ctx.sessionManager.getLeafId(),
  );
  const messages = convertToLlm(sessionContext.messages);

  const questionMessage: UserMessage = {
    role: "user",
    content: [{ type: "text", text: question }],
    timestamp: Date.now(),
  };

  return [...messages, questionMessage];
}

async function runQuery(
  ctx: ExtensionCommandContext,
  question: string,
  signal: AbortSignal,
): Promise<QueryResult> {
  const model = ctx.model;
  if (!model) {
    return { kind: "error", error: new Error("No model selected") };
  }

  const messages = buildMessages(ctx, question);

  try {
    const response = await ctx.modelRegistry.complete(
      model,
      {
        systemPrompt: `${ctx.getSystemPrompt()}\n${SIDE_QUESTION_PROMPT}`,
        messages,
      },
      {
        signal,
        // Reuse the main session's prompt cache for the shared conversation context.
        cacheRetention: "short",
        sessionId: ctx.sessionManager.getSessionId(),
      },
    );

    if (response.stopReason === "aborted") {
      return { kind: "cancelled" };
    }

    if (response.stopReason === "error") {
      return {
        kind: "error",
        error: new Error(response.errorMessage ?? "The model returned an error"),
      };
    }

    const text = extractText(response);
    if (!text) {
      return { kind: "error", error: new Error("The model returned an empty response") };
    }

    return { kind: "answer", text };
  } catch (error) {
    return { kind: "error", error };
  }
}

async function askWithLoader(
  ctx: ExtensionCommandContext,
  question: string,
): Promise<QueryResult> {
  const model = ctx.model;
  if (!model) {
    return { kind: "error", error: new Error("No model selected") };
  }

  return ctx.ui.custom<QueryResult>(
    (tui, theme, _keybindings, done) => {
      const loader = new BorderedLoader(tui, theme, `Asking ${model.id}...`);
      let settled = false;

      const finish = (result: QueryResult) => {
        if (settled) return;
        settled = true;
        done(result);
      };

      loader.onAbort = () => finish({ kind: "cancelled" });

      void runQuery(ctx, question, loader.signal).then(finish, (error) =>
        finish({ kind: "error", error }),
      );

      return loader;
    },
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: "60%",
        maxHeight: "30%",
        margin: 1,
      },
    },
  );
}

async function showAnswer(
  ctx: ExtensionCommandContext,
  question: string,
  answer: string,
): Promise<void> {
  await ctx.ui.custom<void>(
    (_tui, theme, _keybindings, done) => {
      const container = new Container();
      const border = new DynamicBorder((s: string) => theme.fg("accent", s));

      container.addChild(border);
      container.addChild(
        new Text(theme.fg("accent", theme.bold(`btw: ${question}`)), 1, 0),
      );
      container.addChild(new Markdown(answer, 1, 1, getMarkdownTheme()));
      container.addChild(
        new Text(theme.fg("dim", "Press Enter or Esc to close"), 1, 0),
      );
      container.addChild(border);

      return {
        render: (width: number) => container.render(width),
        invalidate: () => container.invalidate(),
        handleInput: (data: string) => {
          if (matchesKey(data, "enter") || matchesKey(data, "escape")) {
            done(undefined);
          }
        },
      };
    },
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: "80%",
        maxHeight: "80%",
        margin: 1,
      },
    },
  );
}

export default function btwExtension(pi: ExtensionAPI): void {
  pi.registerCommand("btw", {
    description: "Ask a temporary question about the current conversation",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("btw requires interactive mode", "error");
        return;
      }

      if (!ctx.model) {
        ctx.ui.notify("No model selected", "error");
        return;
      }

      let question = args.trim();
      if (!question) {
        const input = await ctx.ui.input("btw question", "Ask a temporary question");
        if (input === undefined) return;
        question = input.trim();
      }

      if (!question) {
        ctx.ui.notify("Question cannot be empty", "warning");
        return;
      }

      const result = await askWithLoader(ctx, question);
      if (result.kind === "cancelled") {
        ctx.ui.notify("btw cancelled", "info");
        return;
      }
      if (result.kind === "error") {
        ctx.ui.notify(`btw failed: ${errorMessage(result.error)}`, "error");
        return;
      }

      await showAnswer(ctx, question, result.text);
    },
  });
}

import type {
  AssistantMessage,
  Message,
  UserMessage,
} from "@earendil-works/pi-ai";
import {
  BorderedLoader,
  buildSessionContext,
  convertToLlm,
  DynamicBorder,
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import {
  Markdown,
  matchesKey,
  Text,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";

const SIDE_QUESTION_PROMPT = `
You are answering a temporary side question about an ongoing conversation.

Use the conversation and system context provided to answer the question. This is
not part of the main conversation: do not mention this side exchange as if it
were a user message in the main thread. Do not call tools or make changes; use
only the supplied context. Be concise and answer the question directly.
`;

type QueryResult =
  | { kind: "answer"; text: string; message: AssistantMessage }
  | { kind: "cancelled" }
  | { kind: "error"; error: unknown };

const MAX_SIDE_EXCHANGES = 20;

type SideExchange = {
  question: string;
  answer: string;
  userMessage: UserMessage;
  assistantMessage: AssistantMessage;
};

type SideHistory = {
  exchanges: SideExchange[];
};

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

function getSideMessages(history: SideHistory): Message[] {
  return history.exchanges.flatMap((exchange) => [
    exchange.userMessage,
    exchange.assistantMessage,
  ]);
}

function addSideExchange(
  history: SideHistory,
  question: string,
  answer: string,
  assistantMessage: AssistantMessage,
): number {
  history.exchanges.push({
    question,
    answer,
    userMessage: {
      role: "user",
      content: [{ type: "text", text: question }],
      timestamp: Date.now(),
    },
    assistantMessage,
  });

  if (history.exchanges.length > MAX_SIDE_EXCHANGES) {
    history.exchanges.splice(
      0,
      history.exchanges.length - MAX_SIDE_EXCHANGES,
    );
  }

  return history.exchanges.length - 1;
}

function buildMessages(
  ctx: ExtensionCommandContext,
  question: string,
  sideMessages: Message[],
) {
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

  return [...messages, ...sideMessages, questionMessage];
}

async function runQuery(
  ctx: ExtensionCommandContext,
  question: string,
  sideMessages: Message[],
  signal: AbortSignal,
): Promise<QueryResult> {
  const model = ctx.model;
  if (!model) {
    return { kind: "error", error: new Error("No model selected") };
  }

  const messages = buildMessages(ctx, question, sideMessages);

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

    return {
      kind: "answer",
      text,
      // Keep only the displayed text when carrying this exchange forward.
      // Thinking/tool-call blocks are intentionally not part of the side chat.
      message: {
        ...response,
        content: [{ type: "text", text }],
      },
    };
  } catch (error) {
    return { kind: "error", error };
  }
}

async function askWithLoader(
  ctx: ExtensionCommandContext,
  question: string,
  sideMessages: Message[],
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

      void runQuery(ctx, question, sideMessages, loader.signal).then(finish, (error) =>
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
  history: SideHistory,
  initialIndex: number,
): Promise<void> {
  await ctx.ui.custom<void>(
    (tui, theme, _keybindings, done) => {
      const border = new DynamicBorder((s: string) => theme.fg("accent", s));
      const title = new Text("", 1, 0);
      const markdown = new Markdown("", 1, 1, getMarkdownTheme());
      const footer = new Text(
        theme.fg(
          "dim",
          "Ctrl+A ask · Ctrl+L prev · Ctrl+H next · Ctrl+P/N line · Ctrl+F/B page · Enter/Esc close",
        ),
        1,
        0,
      );
      let selectedIndex = initialIndex;
      let scrollOffset = 0;
      let viewportHeight = 0;
      let asking = false;

      const updateAnswer = () => {
        const exchange = history.exchanges[selectedIndex];
        if (!exchange) return;

        title.setText(
          theme.fg(
            "accent",
            theme.bold(
              `btw [${selectedIndex + 1}/${history.exchanges.length}]: ${exchange.question}`,
            ),
          ),
        );
        markdown.setText(exchange.answer);
        scrollOffset = 0;
      };

      const askAdditionalQuestion = async () => {
        const input = await ctx.ui.input("btw: 追加の質問", "");
        const question = input?.trim();
        if (!question) return;

        const result = await askWithLoader(
          ctx,
          question,
          getSideMessages(history),
        );
        if (result.kind === "cancelled") {
          ctx.ui.notify("btw cancelled", "info");
          return;
        }
        if (result.kind === "error") {
          ctx.ui.notify(`btw failed: ${errorMessage(result.error)}`, "error");
          return;
        }

        selectedIndex = addSideExchange(
          history,
          question,
          result.text,
          result.message,
        );
        updateAnswer();
      };

      updateAnswer();

      const render = (width: number): string[] => {
        const hasSideBorders = width >= 3;
        const contentWidth = hasSideBorders ? width - 2 : width;
        const topBorderLines = hasSideBorders
          ? [
              `${theme.fg("accent", "╭")}${border.render(width - 2)[0]!}${theme.fg("accent", "╮")}`,
            ]
          : border.render(width);
        const bottomBorderLines = hasSideBorders
          ? [
              `${theme.fg("accent", "╰")}${border.render(width - 2)[0]!}${theme.fg("accent", "╯")}`,
            ]
          : border.render(width);
        const titleLines = title.render(contentWidth);
        const answerLines = markdown.render(contentWidth);
        const footerLines = footer.render(contentWidth);
        const addSideBorders = (lines: string[]): string[] => {
          if (!hasSideBorders) {
            return lines.map((line) => truncateToWidth(line, contentWidth, ""));
          }

          return lines.map((line) => {
            const content = truncateToWidth(line, contentWidth, "");
            return `${theme.fg("accent", "│")}${content}${" ".repeat(
              Math.max(0, contentWidth - visibleWidth(content)),
            )}${theme.fg("accent", "│")}`;
          });
        };
        const availableHeight = Math.max(1, tui.terminal.rows - 2);
        const maxHeight = Math.min(
          availableHeight,
          Math.max(1, Math.floor(tui.terminal.rows * 0.8)),
        );
        const fixedHeight =
          topBorderLines.length + bottomBorderLines.length + titleLines.length + footerLines.length;
        viewportHeight = Math.max(0, maxHeight - fixedHeight);
        const maxScrollOffset = Math.max(0, answerLines.length - viewportHeight);

        scrollOffset = Math.min(scrollOffset, maxScrollOffset);

        return [
          ...topBorderLines,
          ...addSideBorders(titleLines),
          ...addSideBorders(
            answerLines.slice(scrollOffset, scrollOffset + viewportHeight),
          ),
          ...addSideBorders(footerLines),
          ...bottomBorderLines,
        ];
      };

      return {
        render,
        invalidate: () => {
          border.invalidate();
          title.invalidate();
          markdown.invalidate();
          footer.invalidate();
        },
        handleInput: (data: string) => {
          // The overlay owns input while open, so these take precedence over
          // the normal editor/selector keybindings.
          if (matchesKey(data, "ctrl+a")) {
            if (asking) return;
            asking = true;
            void askAdditionalQuestion().finally(() => {
              asking = false;
              tui.requestRender();
            });
            return;
          }
          if (matchesKey(data, "ctrl+l")) {
            selectedIndex = Math.max(0, selectedIndex - 1);
            updateAnswer();
            tui.requestRender();
            return;
          }
          if (matchesKey(data, "ctrl+h")) {
            selectedIndex = Math.min(
              history.exchanges.length - 1,
              selectedIndex + 1,
            );
            updateAnswer();
            tui.requestRender();
            return;
          }
          if (matchesKey(data, "ctrl+p")) {
            scrollOffset = Math.max(0, scrollOffset - 1);
            tui.requestRender();
            return;
          }
          if (matchesKey(data, "ctrl+n")) {
            scrollOffset += 1;
            tui.requestRender();
            return;
          }
          if (matchesKey(data, "ctrl+b")) {
            scrollOffset = Math.max(0, scrollOffset - Math.max(1, viewportHeight));
            tui.requestRender();
            return;
          }
          if (matchesKey(data, "ctrl+f")) {
            scrollOffset += Math.max(1, viewportHeight);
            tui.requestRender();
            return;
          }
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
  const sideHistoryBySession = new Map<string, SideHistory>();

  pi.registerCommand("btw", {
    description: "Ask a temporary question with /btw <question>",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("btw requires interactive mode", "error");
        return;
      }

      const sessionId = ctx.sessionManager.getSessionId();
      const history = sideHistoryBySession.get(sessionId);
      const question = args.trim();

      if (!question) {
        if (history && history.exchanges.length > 0) {
          await showAnswer(ctx, history, history.exchanges.length - 1);
        } else {
          ctx.ui.notify("No previous btw answer. Usage: /btw <question>", "info");
        }
        return;
      }

      if (!ctx.model) {
        ctx.ui.notify("No model selected", "error");
        return;
      }

      const currentHistory = history ?? { exchanges: [] };
      const result = await askWithLoader(
        ctx,
        question,
        getSideMessages(currentHistory),
      );
      if (result.kind === "cancelled") {
        ctx.ui.notify("btw cancelled", "info");
        return;
      }
      if (result.kind === "error") {
        ctx.ui.notify(`btw failed: ${errorMessage(result.error)}`, "error");
        return;
      }

      const answerIndex = addSideExchange(
        currentHistory,
        question,
        result.text,
        result.message,
      );
      sideHistoryBySession.set(sessionId, currentHistory);

      await showAnswer(ctx, currentHistory, answerIndex);
    },
  });
}

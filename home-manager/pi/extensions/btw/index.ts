import type {
  AssistantMessage,
  Message,
  UserMessage,
} from "@earendil-works/pi-ai";
import {
  buildSessionContext,
  convertToLlm,
  DynamicBorder,
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import {
  Input,
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

// pi-tui wraps the cursor character in zero-width APC markers so the TUI can
// position the hardware cursor. Other clients (pi-web) print the lines as-is,
// so they have to be removed before rendering there.
function stripCursorMarkers(lines: string[]): string[] {
  return lines.map((line) => line.replace(/\x1b_pi:[^\x07]*\x07/g, ""));
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
        // Some OpenAI-compatible APIs reject an empty tools array.
        onPayload: (payload: unknown) => {
          if (
            payload !== null &&
            typeof payload === "object" &&
            "tools" in payload &&
            Array.isArray(payload.tools) &&
            payload.tools.length === 0
          ) {
            return { ...payload, tools: null };
          }
          return undefined;
        },
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

type PanelMode = "view" | "input" | "loading";

// One panel serves both clients. The TUI allows nested overlays, but pi-web
// renders only the first queued `custom()` UI, so asking, typing and showing
// the answer are modes of a single component instead of stacked overlays.
async function showPanel(
  ctx: ExtensionCommandContext,
  history: SideHistory,
  options: { initialIndex: number; initialQuestion?: string },
): Promise<boolean> {
  let mounted = false;

  await ctx.ui.custom<void>(
    (tui, theme, _keybindings, done) => {
      mounted = true;

      // pi-web exposes a fixed 40x92 fake terminal and only requestRender(), so
      // keep the layout independent of terminal sizing beyond that.
      const border = new DynamicBorder((s: string) => theme.fg("accent", s));
      const title = new Text("", 1, 0);
      const answer = new Markdown("", 1, 1, getMarkdownTheme());
      const input = new Input({ placeholder: "質問を入力" });
      // A spinner would push a full frame through pi-web's stream every 80 ms,
      // so the waiting state is a single static line instead.
      const status = new Text("", 1, 1);
      const footer = new Text("", 1, 0);

      let mode: PanelMode = options.initialQuestion ? "loading" : "view";
      let selectedIndex = options.initialIndex;
      let scrollOffset = 0;
      let viewportHeight = 0;
      let disposed = false;
      let asking = false;
      let controller: AbortController | undefined;

      const finish = () => {
        if (disposed) return;
        disposed = true;
        controller?.abort();
        done(undefined);
      };

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
        answer.setText(exchange.answer);
        scrollOffset = 0;
      };

      const updateFooter = () => {
        const hint =
          mode === "view"
            ? "Ctrl+A ask · ←/→ Ctrl+H/L prev/next · ↑/↓ Ctrl+P/N line · Ctrl+F/B pg · Enter/Esc close"
            : mode === "input"
              ? "Enter 送信 · Esc 戻る"
              : "Esc キャンセル";
        footer.setText(theme.fg("dim", hint));
      };

      const ask = async (question: string) => {
        if (asking || disposed) return;
        asking = true;
        mode = "loading";
        scrollOffset = 0;
        status.setText(
          theme.fg("accent", `Asking ${ctx.model?.id ?? "the model"}...`),
        );
        updateFooter();
        controller = new AbortController();
        tui.requestRender();

        const result = await runQuery(
          ctx,
          question,
          getSideMessages(history),
          controller.signal,
        );

        asking = false;
        controller = undefined;
        if (disposed) return;

        mode = "view";
        if (result.kind === "answer") {
          selectedIndex = addSideExchange(
            history,
            question,
            result.text,
            result.message,
          );
        } else if (result.kind === "cancelled") {
          ctx.ui.notify("btw cancelled", "info");
        } else {
          ctx.ui.notify(`btw failed: ${errorMessage(result.error)}`, "error");
        }

        if (history.exchanges.length === 0) {
          // Nothing to show: close instead of leaving an empty panel behind.
          finish();
          return;
        }

        updateAnswer();
        updateFooter();
        tui.requestRender();
      };

      input.onSubmit = (value: string) => {
        const question = value.trim();
        if (!question) {
          mode = "view";
          updateFooter();
          tui.requestRender();
          return;
        }
        void ask(question);
      };
      input.onEscape = () => {
        mode = "view";
        updateFooter();
        tui.requestRender();
      };

      const openInput = () => {
        input.setValue("");
        mode = "input";
        updateFooter();
        tui.requestRender();
      };

      const selectExchange = (delta: number) => {
        const last = Math.max(0, history.exchanges.length - 1);
        selectedIndex = Math.min(last, Math.max(0, selectedIndex + delta));
        updateAnswer();
        tui.requestRender();
      };

      const scrollLines = (delta: number) => {
        scrollOffset = Math.max(0, scrollOffset + delta);
        tui.requestRender();
      };

      const scrollPages = (direction: -1 | 1) => {
        scrollOffset = Math.max(
          0,
          scrollOffset + direction * Math.max(1, viewportHeight),
        );
        tui.requestRender();
      };

      // Kick off the first request inside the panel so the initial question and
      // the follow-up share one component (and therefore one UI in pi-web).
      if (options.initialQuestion) {
        void ask(options.initialQuestion);
      } else {
        updateAnswer();
      }
      updateFooter();

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
        const addSideBorders = (lines: readonly string[]): string[] => {
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

        const titleLines = title.render(contentWidth);
        const footerLines = footer.render(contentWidth);
        const availableHeight = Math.max(1, tui.terminal.rows - 2);
        const maxHeight = Math.min(
          availableHeight,
          Math.max(1, Math.floor(tui.terminal.rows * 0.8)),
        );
        const bodyHeight = Math.max(
          1,
          maxHeight -
            topBorderLines.length -
            bottomBorderLines.length -
            titleLines.length -
            footerLines.length,
        );

        let bodyLines: readonly string[];
        if (mode === "loading") {
          viewportHeight = 0;
          bodyLines = status.render(contentWidth);
        } else if (mode === "input") {
          viewportHeight = 0;
          bodyLines = ["", ...input.render(contentWidth)];
        } else {
          const answerLines = answer.render(contentWidth);
          viewportHeight = bodyHeight;
          scrollOffset = Math.min(
            scrollOffset,
            Math.max(0, answerLines.length - viewportHeight),
          );
          bodyLines = answerLines.slice(
            scrollOffset,
            scrollOffset + viewportHeight,
          );
        }

        const lines = [
          ...topBorderLines,
          ...addSideBorders(titleLines),
          ...addSideBorders(bodyLines.slice(0, bodyHeight)),
          ...addSideBorders(footerLines),
          ...bottomBorderLines,
        ];

        return ctx.mode === "tui" ? lines : stripCursorMarkers(lines);
      };

      return {
        render,
        invalidate: () => {
          border.invalidate();
          title.invalidate();
          answer.invalidate();
          input.invalidate();
          status.invalidate();
          footer.invalidate();
        },
        dispose: () => {
          // pi-web disposes the component when the client goes away or aborts.
          disposed = true;
          controller?.abort();
        },
        get focused() {
          return input.focused;
        },
        set focused(focused: boolean) {
          input.focused = focused;
        },
        handleInput: (data: string) => {
          if (mode === "loading") {
            if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
              controller?.abort();
            }
            return;
          }

          if (mode === "input") {
            // Ctrl+C closes the prompt; every other key belongs to the input.
            if (matchesKey(data, "ctrl+c")) {
              mode = "view";
              updateFooter();
              tui.requestRender();
              return;
            }
            input.handleInput(data);
            tui.requestRender();
            return;
          }

          // The overlay owns input while open, so these take precedence over
          // the normal editor/selector keybindings.
          if (matchesKey(data, "ctrl+a")) {
            openInput();
            return;
          }
          // Arrow keys are aliases for the Ctrl bindings: ←/→ pick an exchange,
          // ↑/↓ scroll one line.
          if (matchesKey(data, "ctrl+h") || matchesKey(data, "left")) {
            selectExchange(-1);
            return;
          }
          if (matchesKey(data, "ctrl+l") || matchesKey(data, "right")) {
            selectExchange(1);
            return;
          }
          if (matchesKey(data, "ctrl+p") || matchesKey(data, "up")) {
            scrollLines(-1);
            return;
          }
          if (matchesKey(data, "ctrl+n") || matchesKey(data, "down")) {
            scrollLines(1);
            return;
          }
          if (matchesKey(data, "ctrl+b")) {
            scrollPages(-1);
            return;
          }
          if (matchesKey(data, "ctrl+f")) {
            scrollPages(1);
            return;
          }
          if (matchesKey(data, "enter") || matchesKey(data, "escape")) {
            finish();
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

  return mounted;
}

export default function btwExtension(pi: ExtensionAPI): void {
  const sideHistoryBySession = new Map<string, SideHistory>();

  pi.registerCommand("btw", {
    description: "Ask a temporary question with /btw <question>",
    handler: async (args, ctx) => {
      // `hasUI` is true in the TUI and in RPC clients that implement the
      // extension UI sub-protocol (pi-web does).
      if (!ctx.hasUI) {
        ctx.ui.notify("btw requires an interactive UI", "error");
        return;
      }

      const sessionId = ctx.sessionManager.getSessionId();
      const question = args.trim();
      const history = sideHistoryBySession.get(sessionId) ?? { exchanges: [] };

      if (!question && history.exchanges.length === 0) {
        ctx.ui.notify("No previous btw answer. Usage: /btw <question>", "info");
        return;
      }
      if (question && !ctx.model) {
        ctx.ui.notify("No model selected", "error");
        return;
      }

      sideHistoryBySession.set(sessionId, history);

      const mounted = await showPanel(ctx, history, {
        initialIndex: Math.max(0, history.exchanges.length - 1),
        initialQuestion: question || undefined,
      });
      if (mounted || !question) return;

      // A client without `custom()` support (plain `pi --mode rpc`) never runs
      // the panel factory, so answer the question in a dialog instead.
      const result = await runQuery(
        ctx,
        question,
        getSideMessages(history),
        new AbortController().signal,
      );
      if (result.kind === "cancelled") {
        ctx.ui.notify("btw cancelled", "info");
      } else if (result.kind === "error") {
        ctx.ui.notify(`btw failed: ${errorMessage(result.error)}`, "error");
      } else {
        addSideExchange(history, question, result.text, result.message);
        await ctx.ui.editor(`btw: ${question}`, result.text);
      }
    },
  });
}

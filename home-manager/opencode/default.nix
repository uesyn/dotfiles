{
  config,
  pkgs,
  lib,
  ...
}@inputs:
let
  opencode =
    inputs.opencode or {
      provider = { };
    };
  defaultProvider = {
    "ai-engine" = {
      npm = "@ai-sdk/openai-compatible";
      name = "AI Engine";
      models = {
        "Qwen3-Coder-480B-A35B-Instruct-FP8" = {
          name = "Qwen3-Coder-480B-A35B-Instruct-FP8";
        };
        "Qwen3-Coder-30B-A3B-Instruct" = {
          name = "Qwen3-Coder-30B-A3B-Instruct";
        };
      };
      options = {
        baseURL = "https://api.ai.sakura.ad.jp/v1";
        apiKey = "{env:AI_ENGINE_DEV_API_KEY}";
      };
    };
  };
  provider = defaultProvider // opencode.provider;
  jsonProvider = builtins.toJSON provider;
in
{
  home.packages = [
    pkgs.opencode
  ];
  home.sessionVariables = {
    OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
  };
  home.file = {
    ".config/opencode/opencode.jsonc".text = ''
      {
        "$schema": "https://opencode.ai/tui.json",
        "autoupdate": false,
        "plugin": ["opencode-antigravity-auth@latest"],
        "provider": ${jsonProvider}
      }
    '';
    ".config/opencode/tui.json".text = ''
      {
        "$schema": "https://opencode.ai/tui.json",
        "theme": "dracula",
        "keybinds": {
          "leader": "ctrl+x",
          "editor_open": "ctrl+o",
          "theme_list": "none",
          "sidebar_toggle": "none",
          "scrollbar_toggle": "none",
          "username_toggle": "none",
          "status_view": "none",
          "tool_details": "none",
          "session_export": "none",
          "session_new": "none",
          "session_list": "none",
          "session_timeline": "none",
          "session_fork": "none",
          "session_rename": "none",
          "session_share": "none",
          "session_unshare": "none",
          "session_interrupt": "escape",
          "session_compact": "none",
          "session_child_cycle": "none",
          "session_child_cycle_reverse": "none",
          "session_parent": "none",
          "messages_page_up": "ctrl+b",
          "messages_page_down": "ctrl+f",
          "messages_line_up": "ctrl+p",
          "messages_line_down": "ctrl+n",
          "messages_half_page_up": "none",
          "messages_half_page_down": "none",
          "messages_first": "none",
          "messages_last": "none",
          "messages_next": "none",
          "messages_previous": "none",
          "messages_copy": "<leader>y",
          "messages_undo": "<leader>u",
          "messages_redo": "<leader>r",
          "messages_last_user": "none",
          "messages_toggle_conceal": "none",
          "model_list": "none",
          "model_cycle_recent": "none",
          "model_cycle_recent_reverse": "none",
          "model_cycle_favorite": "none",
          "model_cycle_favorite_reverse": "none",
          "variant_cycle": "none",
          "command_list": "<leader>p",
          "agent_list": "none",
          "agent_cycle": "tab",
          "agent_cycle_reverse": "shift+tab",
          "input_clear": "none",
          "input_paste": "ctrl+v,ctrl+shift+v",
          "input_submit": "return",
          "input_newline": "none",
          "input_move_left": "left",
          "input_move_right": "right",
          "input_move_up": "up",
          "input_move_down": "down",
          "input_select_left": "none",
          "input_select_right": "none",
          "input_select_up": "none",
          "input_select_down": "none",
          "input_line_home": "ctrl+a",
          "input_line_end": "ctrl+e",
          "input_select_line_home": "none",
          "input_select_line_end": "none",
          "input_visual_line_home": "none",
          "input_visual_line_end": "none",
          "input_select_visual_line_home": "none",
          "input_select_visual_line_end": "none",
          "input_buffer_home": "none",
          "input_buffer_end": "none",
          "input_select_buffer_home": "none",
          "input_select_buffer_end": "none",
          "input_delete_line": "none",
          "input_delete_to_line_end": "ctrl+k",
          "input_delete_to_line_start": "ctrl+u",
          "input_backspace": "backspace,shift+backspace",
          "input_delete": "ctrl+d,delete,shift+delete",
          "input_undo": "none",
          "input_redo": "none",
          "input_word_forward": "alt+f,alt+right,ctrl+right",
          "input_word_backward": "alt+b,alt+left,ctrl+left",
          "input_select_word_forward": "none",
          "input_select_word_backward": "none",
          "input_delete_word_forward": "alt+d,alt+delete,ctrl+delete",
          "input_delete_word_backward": "ctrl+w,ctrl+backspace,alt+backspace",
          "history_previous": "up",
          "history_next": "down",
          "terminal_suspend": "ctrl+z",
          "terminal_title_toggle": "none",
          "tips_toggle": "none",
          "display_thinking": "none"
        }
      }
    '';
    ".config/opencode/themes/dracula.json".text = ''
      {
        "$schema": "https://opencode.ai/theme.json",
        "defs": {
          "bgPrimary": "#282A36",
          "bgSecondary": "#44475A",
          "bgSelection": "#44475A",
          "foreground": "#F8F8F2",
          "comment": "#6272A4",
          "red": "#FF5555",
          "orange": "#FFB86C",
          "yellow": "#F1FA8C",
          "green": "#50FA7B",
          "cyan": "#8BE9FD",
          "purple": "#BD93F9",
          "pink": "#FF79C6",
          "bgDiffAdded": "#2B3A2F",
          "bgDiffRemoved": "#3D2A2E"
        },
        "theme": {
          "primary": "purple",
          "secondary": "cyan",
          "accent": "pink",
          "error": "red",
          "warning": "orange",
          "success": "green",
          "info": "cyan",
          "text": "foreground",
          "textMuted": "comment",
          "background": "bgPrimary",
          "backgroundPanel": "bgSecondary",
          "backgroundElement": "bgSecondary",
          "border": "bgSelection",
          "borderActive": "purple",
          "borderSubtle": "bgSelection",
          "diffAdded": "green",
          "diffRemoved": "red",
          "diffContext": "foreground",
          "diffHunkHeader": "comment",
          "diffHighlightAdded": "green",
          "diffHighlightRemoved": "red",
          "diffAddedBg": "bgDiffAdded",
          "diffRemovedBg": "bgDiffRemoved",
          "diffContextBg": "bgSecondary",
          "diffLineNumber": "comment",
          "diffAddedLineNumberBg": "bgDiffAdded",
          "diffRemovedLineNumberBg": "bgDiffRemoved",
          "markdownText": "foreground",
          "markdownHeading": "purple",
          "markdownLink": "cyan",
          "markdownLinkText": "pink",
          "markdownCode": "green",
          "markdownBlockQuote": "comment",
          "markdownEmph": "yellow",
          "markdownStrong": "orange",
          "markdownHorizontalRule": "comment",
          "markdownListItem": "cyan",
          "markdownListEnumeration": "purple",
          "markdownImage": "pink",
          "markdownImageText": "yellow",
          "markdownCodeBlock": "green",
          "syntaxComment": "comment",
          "syntaxKeyword": "pink",
          "syntaxFunction": "green",
          "syntaxVariable": "foreground",
          "syntaxString": "yellow",
          "syntaxNumber": "purple",
          "syntaxType": "cyan",
          "syntaxOperator": "pink",
          "syntaxPunctuation": "foreground"
        }
      }
    '';
  };
}

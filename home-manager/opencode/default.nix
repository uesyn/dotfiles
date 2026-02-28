{
  config,
  pkgs,
  lib,
  ...
}@inputs:
let
  defaultProvider = {
    "AI Engine" = {
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
      };
    };
  };
  provider = defaultProvider;
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
        "provider": ${jsonProvider}
      }
    '';
    ".config/opencode/tui.json".text = ''
      {
        "$schema": "https://opencode.ai/tui.json",
        "theme": "dracula",
        "keybinds": {
          "leader": "ctrl+x",
          "app_exit": "ctrl+c,ctrl+d,<leader>q",
          "editor_open": "<leader>e",
          "theme_list": "<leader>t",
          "sidebar_toggle": "<leader>b",
          "scrollbar_toggle": "none",
          "username_toggle": "none",
          "status_view": "<leader>s",
          "tool_details": "none",
          "session_export": "<leader>x",
          "session_new": "<leader>n",
          "session_list": "<leader>l",
          "session_timeline": "<leader>g",
          "session_fork": "none",
          "session_rename": "none",
          "session_share": "none",
          "session_unshare": "none",
          "session_interrupt": "escape",
          "session_compact": "<leader>c",
          "session_child_cycle": "<leader>right",
          "session_child_cycle_reverse": "<leader>left",
          "session_parent": "<leader>up",
          "messages_page_up": "pageup,ctrl+alt+b",
          "messages_page_down": "pagedown,ctrl+alt+f",
          "messages_line_up": "ctrl+alt+y",
          "messages_line_down": "ctrl+alt+e",
          "messages_half_page_up": "ctrl+alt+u",
          "messages_half_page_down": "ctrl+alt+d",
          "messages_first": "ctrl+g,home",
          "messages_last": "ctrl+alt+g,end",
          "messages_next": "none",
          "messages_previous": "none",
          "messages_copy": "<leader>y",
          "messages_undo": "<leader>u",
          "messages_redo": "<leader>r",
          "messages_last_user": "none",
          "messages_toggle_conceal": "<leader>h",
          "model_list": "<leader>m",
          "model_cycle_recent": "f2",
          "model_cycle_recent_reverse": "shift+f2",
          "model_cycle_favorite": "none",
          "model_cycle_favorite_reverse": "none",
          "variant_cycle": "ctrl+t",
          "command_list": "ctrl+p",
          "agent_list": "<leader>a",
          "agent_cycle": "tab",
          "agent_cycle_reverse": "shift+tab",
          "input_clear": "ctrl+c",
          "input_paste": "ctrl+v",
          "input_submit": "return",
          "input_newline": "shift+return,ctrl+return,alt+return,ctrl+j",
          "input_move_left": "left,ctrl+b",
          "input_move_right": "right,ctrl+f",
          "input_move_up": "up",
          "input_move_down": "down",
          "input_select_left": "shift+left",
          "input_select_right": "shift+right",
          "input_select_up": "shift+up",
          "input_select_down": "shift+down",
          "input_line_home": "ctrl+a",
          "input_line_end": "ctrl+e",
          "input_select_line_home": "ctrl+shift+a",
          "input_select_line_end": "ctrl+shift+e",
          "input_visual_line_home": "alt+a",
          "input_visual_line_end": "alt+e",
          "input_select_visual_line_home": "alt+shift+a",
          "input_select_visual_line_end": "alt+shift+e",
          "input_buffer_home": "home",
          "input_buffer_end": "end",
          "input_select_buffer_home": "shift+home",
          "input_select_buffer_end": "shift+end",
          "input_delete_line": "ctrl+shift+d",
          "input_delete_to_line_end": "ctrl+k",
          "input_delete_to_line_start": "ctrl+u",
          "input_backspace": "backspace,shift+backspace",
          "input_delete": "ctrl+d,delete,shift+delete",
          "input_undo": "ctrl+-,super+z",
          "input_redo": "ctrl+.,super+shift+z",
          "input_word_forward": "alt+f,alt+right,ctrl+right",
          "input_word_backward": "alt+b,alt+left,ctrl+left",
          "input_select_word_forward": "alt+shift+f,alt+shift+right",
          "input_select_word_backward": "alt+shift+b,alt+shift+left",
          "input_delete_word_forward": "alt+d,alt+delete,ctrl+delete",
          "input_delete_word_backward": "ctrl+w,ctrl+backspace,alt+backspace",
          "history_previous": "up",
          "history_next": "down",
          "terminal_suspend": "ctrl+z",
          "terminal_title_toggle": "none",
          "tips_toggle": "<leader>h",
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

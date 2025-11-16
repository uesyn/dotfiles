{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  home.packages = [
      pkgs.opencode
  ];
  xdg.configFile = {
    "opencode/config.json".text = ''
      {
        "$schema": "https://opencode.ai/config.json",
        "provider": {
          "aiengine": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "AI Engine",
            "options": {
              "apiKey": "{env:OPENAI_API_KEY}",
              "baseURL": "https://api.ai.sakura.ad.jp/v1/"
            },
            "models": {
              "Qwen3-Coder-480B-A35B-Instruct-FP8": { "name": "(AI Engine) Qwen3-Coder-480B-A35B-Instruct-FP8" }
            }
          },
        },
        "theme": "dracula",
        "model": "aiengine/Qwen3-Coder-480B-A35B-Instruct-FP8",
      }
    '';
    "opencode/themes/dracula.json".text = ''
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

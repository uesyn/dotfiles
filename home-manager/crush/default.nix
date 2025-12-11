{
  config,
  pkgs,
  lib,
  ...
}@inputs:
let
  crush =
    inputs.crush or {
      providers = { };
    };
  defaultProviders = {
    "AI Engine" = {
      name = "AI Engine";
      "base_url" = "https://api.ai.sakura.ad.jp/v1";
      api_key = "$AI_ENGINE_API_KEY";
      type = "openai-compat";
      models = [
        {
          name = "Qwen3-Coder-480B-A35B-Instruct-FP8";
          id = "Qwen3-Coder-480B-A35B-Instruct-FP8";
          "context_window" = 135000;
          "default_max_tokens" = 20000;
        }
        {
          name = "Qwen3-Coder-30B-A3B-Instruct";
          id = "Qwen3-Coder-30B-A3B-Instruct";
          "context_window" = 135000;
          "default_max_tokens" = 20000;
        }
      ];
    };
  };
  providers = defaultProviders // crush.providers;
  jsonProviders = builtins.toJSON providers;
in
{
  home.packages = [
    pkgs.crush
  ];
  home.file = {
    ".config/crush/crush.json".text = ''
      {
        "options": {
          "disable_auto_summarize": true
        },
        "providers": ${jsonProviders},
        "permissions": {
          "allowed_tools": [ "view" ]
        },
        "lsp": {
          "go": {
            "command": "gopls"
          },
          "typescript": {
            "command": "typescript-language-server",
            "args": ["--stdio"]
          },
          "php": {
            "command": "phpactor",
            "args": ["language-server"],
            "filetypes": [
              "php"
            ],
            "root_makers": [
              "composer.json",
              ".git"
            ]
          }
        }
      }
    '';
  };
}

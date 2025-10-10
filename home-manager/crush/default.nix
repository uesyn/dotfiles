{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.crush
  ];
  home.file = {
    ".config/crush/crush.json".text = ''
      {
        "providers": {
          "AI Engine": {
            "name": "Ollama",
            "base_url": "https://api.ai.sakura.ad.jp/v1",
            "type": "openai",
            "models": [
              {
                "name": "Qwen3-Coder-480B-A35B-Instruct-FP8",
                "id": "Qwen3-Coder-480B-A35B-Instruct-FP8",
                "context_window": 256000,
                "default_max_tokens": 20000
              }
            ]
          }
        },
        "lsp": {
          "go": {
            "command": "gopls"
          }
        }
      }
    '';
  };
}

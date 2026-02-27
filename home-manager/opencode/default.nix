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
    ".config/opencode/opencode.json".text = ''
      {
        "$schema": "https://opencode.ai/config.json",
        "theme": "tokyonight",
        "provider": ${jsonProvider}
      }
    '';
  };
}

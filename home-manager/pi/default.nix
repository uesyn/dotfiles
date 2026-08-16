{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.pi = {
    providers = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = ''
        Additional Pi model providers. Provider names are merged with the
        built-in providers; setting an existing provider replaces it.
      '';
      example = lib.literalExpression ''
        {
          openrouter = {
            name = "OpenRouter";
            baseUrl = "https://openrouter.ai/api/v1";
            api = "openai-completions";
            apiKey = "$OPENROUTER_API_KEY";
            models = [
              { id = "openai/gpt-4o"; }
            ];
          };
        }
      '';
    };
  };

  config =
    let
      pi = config.dotfiles.pi;
      defaultProviders = {
        "ai-engine" = {
          name = "AI Engine";
          baseUrl = "https://api.ai.sakura.ad.jp/v1";
          api = "openai-completions";
          apiKey = "$AI_ENGINE_API_KEY";
          models = [
            { id = "Qwen3-Coder-480B-A35B-Instruct-FP8"; }
            { id = "Qwen3-Coder-30B-A3B-Instruct"; }
            { id = "preview/Kimi-K2.6"; }
            { id = "preview/Kimi-K2.7-Code"; }
          ];
        };
      };
      providers = defaultProviders // pi.providers;
    in
    {
      home.file.".local/share/pi/extensions/btw.ts".source = ./extensions/btw.ts;
      home.file.".local/share/pi/extensions/dynamic-provider.ts".source =
        ./extensions/dynamic-provider.ts;
      home.file.".local/share/pi/extensions/last-model.ts".source = ./extensions/last-model.ts;
      home.file.".local/share/pi/extensions/plan-mode.ts".source = ./extensions/plan-mode.ts;
      home.file.".local/share/pi/extensions/web-search.ts".source = ./extensions/web-search.ts;

      programs.pi-coding-agent = {
        enable = true;
        extraPackages = [
          pkgs.nodejs
          pkgs.bun
        ];
        models.providers = providers;
        keybindings = {
          # Make Ctrl+C a clean exit (/quit equivalent) instead of clear/exit-on-second-press.
          "app.clear" = [ ];
          "app.exit" = [
            "ctrl+c"
            "ctrl+d"
          ];
          "app.model.cycleBackward" = [ ];
          "app.model.cycleForward" = [ ];
          "app.model.select" = [ ];
          "app.models.toggleProvider" = [ ];
          "app.session.togglePath" = [ ];
          "app.tree.filter.labeledOnly" = [ ];
          "tui.select.up" = [
            "up"
            "ctrl+p"
          ];
          "tui.select.down" = [
            "down"
            "ctrl+n"
          ];
        };
        settings = {
          compaction = {
            enabled = true;
            keepRecentTokens = 20000;
            reserveTokens = 16384;
          };
          extensions = [
            "${config.home.homeDirectory}/.local/share/pi/extensions/btw.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/autocomplete-priority.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/dynamic-provider.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/last-model.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/plan-mode.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/web-search.ts"
          ];
          packages = [ ];
          skills = [
            "${config.home.homeDirectory}/.config/opencode/skills"
          ];
          retry = {
            enabled = true;
            maxRetries = 3;
          };
          theme = "dark";
        };
      };
    };
}

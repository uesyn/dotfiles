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
    systemPromptModifier = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            prepend = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Text prepended to the model's system prompt.";
            };
            append = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Text appended to the model's system prompt.";
            };
          };
        }
      );
      default = { };
      description = ''
        Per-model system prompt modifiers for the `systemp-prompt-modifier`
        extension. Attribute names are Pi model identifiers of the form
        `provider/model-id`. `prepend` and `append` are joined with the
        model's system prompt (separated by newlines). Models without any
        modifier content are omitted, and the configuration file is only
        generated when at least one model defines content.
      '';
      example = lib.literalExpression ''
        {
          "ai-engine/preview/Kimi-K2.7-Code" = {
            prepend = "Always respond in Japanese.";
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
      systemPromptModifiers = lib.mapAttrs (
        _: modifier: lib.filterAttrs (_: text: text != null) modifier
      ) pi.systemPromptModifier;
    in
    {
      home.packages = [ pkgs.llm-agents.code-review-graph ];

      home.file.".pi/agent/mcp.json".text = builtins.toJSON {
        mcpServers = {
          "code-review-graph" = {
            command = lib.getExe pkgs.llm-agents.code-review-graph;
            args = [
              "serve"
              "--auto-watch"
            ];
            lifecycle = "keep-alive";
            requestTimeoutMs = 120000;
          };
          "exa" = {
            url = "https://mcp.exa.ai/mcp";
            headers."x-api-key" = "\${EXA_API_KEY}";
            lifecycle = "lazy";
            requestTimeoutMs = 60000;
            toolPrefix = "none";
            directTools = [
              "web_search_exa"
            ];
          };
        };
      };

      home.file.".pi/agent/system-prompt-modifier.json" = lib.mkIf (systemPromptModifiers != { }) {
        text = builtins.toJSON {
          models = systemPromptModifiers;
        };
      };

      home.file.".local/share/pi/extensions/btw.ts".source = ./extensions/btw.ts;
      home.file.".local/share/pi/extensions/directory-tree.ts".source = ./extensions/directory-tree.ts;
      home.file.".local/share/pi/extensions/dynamic-provider.ts".source =
        ./extensions/dynamic-provider.ts;
      home.file.".local/share/pi/extensions/last-model.ts".source = ./extensions/last-model.ts;
      home.file.".local/share/pi/extensions/notification.ts".source = ./extensions/notification.ts;
      home.file.".local/share/pi/extensions/plan-mode.ts".source = ./extensions/plan-mode.ts;
      home.file.".local/share/pi/extensions/systemp-prompt-modifier.ts".source =
        ./extensions/systemp-prompt-modifier.ts;
      home.file.".local/share/pi/extensions/undo" = {
        source = ./extensions/undo;
        recursive = true;
      };

      programs.pi-coding-agent = {
        enable = true;
        extraPackages = [
          pkgs.nodejs
          pkgs.bun
          pkgs.git
          pkgs.llm-agents.code-review-graph
        ];
        models.providers = providers;
        keybindings = {
          "app.model.cycleBackward" = [ ];
          "app.model.cycleForward" = [ ];
          "app.model.select" = [ ];
          "app.models.toggleProvider" = [ ];
          "app.session.toggleNamedFilter" = [ ];
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
            "${config.home.homeDirectory}/.local/share/pi/extensions/directory-tree.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/autocomplete-priority.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/dynamic-provider.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/last-model.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/notification.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/plan-mode.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/undo"
            "${config.home.homeDirectory}/.local/share/pi/extensions/systemp-prompt-modifier.ts"
          ];
          packages = [
            "npm:pi-mcp-adapter@2.32.1"
          ];
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

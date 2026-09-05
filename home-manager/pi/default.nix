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
      codeReviewGraphTools = [
        "build_or_update_graph_tool"
        "get_minimal_context_tool"
        "get_review_context_tool"
        "get_impact_radius_tool"
        "detect_changes_tool"
        "query_graph_tool"
        "semantic_search_nodes_tool"
        "list_graph_stats_tool"
        "get_architecture_overview_tool"
        "get_affected_flows_tool"
      ];
      codeReviewGraphDirectTools = [
        "build_or_update_graph_tool"
        "get_minimal_context_tool"
        "get_review_context_tool"
        "get_impact_radius_tool"
        "detect_changes_tool"
        "query_graph_tool"
      ];
    in
    {
      home.packages = [ pkgs.llm-agents.code-review-graph ];

      home.file.".pi/agent/mcp.json".text = builtins.toJSON {
        settings = {
          hostConfigDiscovery = "off";
          toolPrefix = "server";
          toolResultRendering = "compact";
        };
        mcpServers = {
          "code-review-graph" = {
            command = lib.getExe pkgs.llm-agents.code-review-graph;
            args = [
              "serve"
              "--auto-watch"
              "--tools"
              (lib.concatStringsSep "," codeReviewGraphTools)
            ];
            lifecycle = "lazy-keep-alive";
            requestTimeoutMs = 120000;
            directTools = codeReviewGraphDirectTools;
          };
        };
      };

      home.file.".pi/agent/skills/code-review-graph/SKILL.md".source =
        ./skills/code-review-graph/SKILL.md;

      home.file.".local/share/pi/extensions/btw.ts".source = ./extensions/btw.ts;
      home.file.".local/share/pi/extensions/directory-tree.ts".source = ./extensions/directory-tree.ts;
      home.file.".local/share/pi/extensions/dynamic-provider.ts".source =
        ./extensions/dynamic-provider.ts;
      home.file.".local/share/pi/extensions/last-model.ts".source = ./extensions/last-model.ts;
      home.file.".local/share/pi/extensions/notification.ts".source = ./extensions/notification.ts;
      home.file.".local/share/pi/extensions/plan-mode.ts".source = ./extensions/plan-mode.ts;
      home.file.".local/share/pi/extensions/web-search.ts".source = ./extensions/web-search.ts;
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
            "${config.home.homeDirectory}/.local/share/pi/extensions/web-search.ts"
            "${config.home.homeDirectory}/.local/share/pi/extensions/undo"
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

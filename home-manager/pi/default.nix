{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ./pi-web-tailcat.nix ];

  options.dotfiles.pi = {
    # Bash tool sandbox bootstrap, generated below and read by bash-sandbox.
    sandbox.profile = lib.mkOption {
      type = lib.types.str;
      default = "agents";
      description = ''
        Existing nono profile name or absolute profile path used for Pi's bash
        and !/!! commands. Defaults to the previously used agents profile. Pi
        runs normally; the extension invokes nono per command. Explicit outer
        sandboxing still limits the grants available to that profile.
      '';
    };

    toolToggle.disabledByDefault = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "gh" ];
      description = ''
        Pi tool names disabled at session start. They can be enabled for the
        current session with /tool. Unknown names are allowed for late tools.
      '';
      example = [ "gh" "mcp__exa__web_search_exa" ];
    };

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
      skills = inputs.anthropic-skills;
      kubebuilder = inputs.kubebuilder;
      # The extension only swaps `shellPath`. This immutable wrapper turns that
      # shell into `nono run ... <nix bash> "$@"`, so Pi keeps owning spawn,
      # timeout, process-tree termination and exit cleanup.
      bashSandbox = pkgs.writeShellScript "nono-bash" ''
        set +u
        # Pi is never started inside nono; this only keeps an accidental nested
        # run from joining an outer broker and inheriting its grants.
        for name in ''${!NONO_@}; do unset "$name"; done
        unset NODE_OPTIONS NODE_PATH BASH_ENV ENV
        exec ${lib.getExe pkgs.nono} run -s --profile ${lib.escapeShellArg pi.sandbox.profile} --allow-cwd --workdir "$PWD" --no-rollback --no-audit --no-diagnostics -- ${pkgs.bash}/bin/bash "$@"
      '';
      # Pi resolves entry-point symlinks before loading imports. Keep sibling
      # extensions in one store tree so their relative imports still resolve.
      # Pin the bash wrapper and read-only tool executables at build time, so
      # the extensions do not resolve them through PATH or runtime configuration.
      extensionsTree = pkgs.runCommand "pi-extensions" { } ''
        cp -r ${./extensions} $out
        chmod -R u+w $out
        substituteInPlace $out/bash-sandbox/endpoint.ts \
          --replace-fail '@sandboxShell@' '${bashSandbox}'
        substituteInPlace $out/gh-readonly/endpoint.ts \
          --replace-fail '@ghExecutable@' '${lib.getExe pkgs.gh}'
        substituteInPlace $out/git-readonly/endpoint.ts \
          --replace-fail '@gitExecutable@' '${lib.getExe pkgs.git}'
      '';
    in
    {
      # Pi runs outside nono, so this module contributes no nono grants; the
      # bash-sandbox extension runs bash and !/!! through nono instead.

      # pi-web comes from npm through mise (the npm backend needs `npm`, which
      # the javascript module provides). Its install directory is writable,
      # which pi-web needs: it rewrites `.next/prerender-manifest.json` on every
      # start so the `previewModeId` published in the package cannot bypass its
      # password gate. `lib.mkDefault` so a plain definition overrides it.
      dotfiles.mise.tools."npm:@agegr/pi-web" = lib.mkDefault "0.17.0";

      home.file.".local/share/pi/extensions".source = "${extensionsTree}";
      # Built-in MCP support (no pi-mcp-adapter package): servers in
      # ~/.pi/agent/mcp.json are connected directly. Tool names are
      # mcp__<server>__<tool>; `exposure = "direct"` declares them to the model.
      home.file.".pi/agent/mcp.json".text = builtins.toJSON {
        mcpServers = {
          "exa" = {
            url = "https://mcp.exa.ai/mcp";
            timeout = 60;
            exposure = "direct";
          };
        };
      };

      home.file.".pi/agent/tool-toggle.json".text = builtins.toJSON {
        disabledByDefault = pi.toolToggle.disabledByDefault;
      };

      home.file.".pi/agent/system-prompt-modifier.json" = lib.mkIf (systemPromptModifiers != { }) {
        text = builtins.toJSON {
          models = systemPromptModifiers;
        };
      };

      # Skills live under ~/.config/pi/skills; the config below points Pi there.
      xdg.configFile = {
        "pi/skills/skill-creator" = {
          source = "${skills}/skills/skill-creator";
        };
        "pi/skills/k8s-api-conventions" = {
          source = ./skills/k8s-api-conventions;
          recursive = true;
        };
        "pi/skills/kubebuilder" = {
          source = ./skills/kubebuilder;
          recursive = true;
        };
        "pi/skills/kubebuilder/references" = {
          source = "${kubebuilder}/docs";
        };
      };

      programs.pi-coding-agent = {
        enable = true;
        # package = pkgs.llm-agents.pi;
        extraPackages = [
          pkgs.nodejs
          pkgs.bun
          pkgs.git
        ];
        models.providers = providers;
        keybindings = {
          "app.model.cycleBackward" = [ ];
          "app.model.cycleForward" = [ ];
          "app.model.select" = [ ];
          "app.models.save" = [ ];
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
          # Built-in grep/find/ls (off by default) plus codemode.
          defaultTools = [
            "+grep"
            "+find"
            "+ls"
            "+codemode"
            "+git"
            "+gh"
            "+ast_grep"
            "+subagent"
          ];
          extensions = [
            "${config.home.homeDirectory}/.local/share/pi/extensions/ast-grep"
            "${config.home.homeDirectory}/.local/share/pi/extensions/btw"
            "${config.home.homeDirectory}/.local/share/pi/extensions/dynamic-provider"
            "${config.home.homeDirectory}/.local/share/pi/extensions/favorite-models"
            "${config.home.homeDirectory}/.local/share/pi/extensions/gh-readonly"
            "${config.home.homeDirectory}/.local/share/pi/extensions/git-readonly"
            "${config.home.homeDirectory}/.local/share/pi/extensions/last-model"
            "${config.home.homeDirectory}/.local/share/pi/extensions/notification"
            "${config.home.homeDirectory}/.local/share/pi/extensions/bash-sandbox"
            "${config.home.homeDirectory}/.local/share/pi/extensions/plan-mode"
            "${config.home.homeDirectory}/.local/share/pi/extensions/subagent"
            "${config.home.homeDirectory}/.local/share/pi/extensions/systemp-prompt-modifier"
            "${config.home.homeDirectory}/.local/share/pi/extensions/tool-toggle"
          ];
          skills = [
            "${config.home.homeDirectory}/.config/pi/skills"
          ];
          retry = {
            enabled = true;
            maxRetries = 3;
          };
          theme = "dark";
          # Interactive TUI mode; pi v1.0.0 defaults to "fullscreen".
          tuiMode = "regular";
        };
      };
    };
}

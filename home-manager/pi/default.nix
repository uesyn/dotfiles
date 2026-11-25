{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  extensions = [
    { name = "btw"; }
    {
      name = "confluence-readonly";
      tool = "confluence";
    }
    { name = "last-model"; }
    { name = "bash-sandbox"; }
  ];
in
{
  imports = [ ./pi-web-tailcat.nix ];

  options.dotfiles.pi = {
    extensions = lib.listToAttrs (
      map (extension: {
        inherit (extension) name;
        value.enable = lib.mkEnableOption "the ${extension.name} Pi extension" // {
          default = true;
        };
      }) extensions
    );

    pstack.enable = lib.mkEnableOption "the pstack Pi package" // {
      default = true;
    };

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

    confluence.cloudId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Confluence Cloud ID used with a scoped API token.";
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
  };

  config =
    let
      pi = config.dotfiles.pi;
      enabledExtensions = lib.filter (extension: pi.extensions.${extension.name}.enable) extensions;
      defaultProviders = {
        "ai-engine" = {
          name = "AI Engine";
          baseUrl = "https://api.ai.sakura.ad.jp/v1";
          api = "openai-completions";
          apiKey = "$AI_ENGINE_API_KEY";
          models = [
            {
              id = "preview/DeepSeek-V4.1-Flash-1017";
              input = [
                "text"
                "image"
              ];
              reasoning = true;
              thinkingLevelMap = {
                off = "none";
                minimal = null;
                low = "low";
                medium = null;
                high = "high";
                xhigh = "xhigh";
                max = "max";
              };
              compat = {
                thinkingFormat = "openai";
                supportsReasoningEffort = true;
              };
            }
            {
              id = "preview/GLM-5.3-Flash";
              input = [
                "text"
                "image"
              ];
              reasoning = true;
              thinkingLevelMap = {
                off = null;
                minimal = null;
                low = "low";
                medium = null;
                high = "high";
                xhigh = null;
                max = "max";
              };
              compat = {
                thinkingFormat = "openai";
                supportsReasoningEffort = true;
              };
            }
            { id = "preview/Kimi-K2.7-Code"; }
          ];
        };
      };
      providers = defaultProviders // pi.providers;
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
      # Pin the bash wrapper at build time instead of looking it up at runtime.
      extensionsTree = pkgs.runCommand "pi-extensions" { } ''
        cp -r ${./extensions} $out
        chmod -R u+w $out
        substituteInPlace $out/bash-sandbox/endpoint.ts \
          --replace-fail '@sandboxShell@' '${bashSandbox}'
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
      dotfiles.mise.tools."npm:@agegr/pi-web" = lib.mkDefault "0.18.0";

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

      # Themes: user themes live at ~/.pi/agent/themes/<name>.json and the file
      # name must match the theme `name` (the only path Pi hot-reloads). The
      # module has no `themes` option, so the vendored themes are linked here.
      home.file.".pi/agent/themes/dracula.json".source = ./themes/dracula.json;

      home.file.".pi/agent/confluence-readonly.json".text = builtins.toJSON pi.confluence;

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
        # User context file → ~/.pi/agent/AGENTS.md, loaded in every working
        # directory (unlike the project AGENTS.md, which only applies inside
        # this repo). `mkDefault` so a module can still set `context` itself.
        context = lib.mkDefault ./context.md;
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
          packages = lib.mkIf pi.pstack.enable [ "${inputs.pstack-claude}" ];
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
          ] ++ map (extension: "+${extension.tool}") (lib.filter (extension: extension ? tool) enabledExtensions);
          extensions = map (
            extension: "${config.home.homeDirectory}/.local/share/pi/extensions/${extension.name}"
          ) enabledExtensions;
          skills = [
            "${config.home.homeDirectory}/.config/pi/skills"
          ];
          retry = {
            enabled = true;
            maxRetries = 3;
          };
          theme = "dracula";
          # Interactive TUI mode; pi v1.0.0 defaults to "fullscreen".
          tuiMode = "regular";
        };
      };
    };
}

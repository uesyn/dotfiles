{ ... }:
{
  # dotfiles.username = "username";
  # dotfiles.homeDirectory = "/home/username";

  # dotfiles.overlays = [];
  # dotfiles.additionalPackages = pkgs: [ pkgs.sl ];

  # dotfiles.go.private = [];

  # dotfiles.git.user = "username";
  # dotfiles.git.email = "email@example.com";

  # dotfiles.git-credential-oauth.device = false;
  # dotfiles.git-credential-oauth.ghHosts = [
  #   { host = "github.com"; }
  #   # Add additional GitHub Enterprise hosts. Override the bundled
  #   # OAuth app with your own by setting the credentials:
  #   # {
  #   #   host = "github.example.com";
  #   #   oauthClientId = "...";
  #   #   oauthClientSecret = "...";
  #   #   # oauthRedirectURL = "https://github.example.com/oauth/callback";
  #   # }
  # ];

  # dotfiles.fence.allowedDomains = [ "example.com" ];
  # dotfiles.fence.allowedUnixSockets = [ "/var/run/docker.sock" ];
  # dotfiles.fence.deniedCommands = [ "rm" "dd" ];
  # `wrap` commands get a shell alias named `<aliasPrefix><command>`;
  # the default prefix keeps fence reachable as `fence-opencode` / `fence-pi`
  # while the plain names are taken over by nono (see below).
  # dotfiles.fence.wrap = [ "opencode" "pi" ];
  # dotfiles.fence.aliasPrefix = "fence-";

  # nono sandbox profile. `wrap` commands get a shell alias that runs
  # `nono run --profile <profileName> -s --allow-cwd -- <command>`.
  # dotfiles.nono.profileName = "agents";
  # dotfiles.nono.aliasPrefix = "";
  # dotfiles.nono.wrap = [ "opencode" "pi" ];

  # Inside the nono sandbox, `gh` and `git` allow only the read-only
  # operations listed in `ghAllowRules` / `gitAllowPrefixes`+`gitAllowExact`
  # (home-manager/nono/default.nix); everything else — including help for
  # denied commands — is denied. Flags belong after the subcommand path
  # (`gh repo list -R owner/repo`, `git log --oneline`); `gh --version`/
  # `--help` and read-only git commands work.

  # Extra paths merged into the generated nono profile. Defaults are kept;
  # these only append, so the profile can be widened/tightened per machine.
  #   extraReads      -> filesystem.read       (paths, read-only)
  #   extraAllows     -> filesystem.allow      (directories, read+write)
  #   extraAllowFiles -> filesystem.allow_file (single files, read+write)
  #   extraDenys      -> filesystem.deny       (denied paths; must not sit
  #                                             below an allowed parent on
  #                                             Linux or nono refuses to start)
  # dotfiles.nono.extraReads = [ "~/.config/foo" ];
  # dotfiles.nono.extraAllows = [ "~/work" ];
  # dotfiles.nono.extraAllowFiles = [ "~/.foo.rc" ];
  # dotfiles.nono.extraDenys = [ "~/.ssh2" ];

  # Add custom Pi model providers. These are merged with the built-in providers.
  # dotfiles.pi.providers = {
  #   openrouter = {
  #     name = "OpenRouter";
  #     baseUrl = "https://openrouter.ai/api/v1";
  #     api = "openai-completions";
  #     apiKey = "$OPENROUTER_API_KEY";
  #     models = [
  #       { id = "openai/gpt-4o"; }
  #     ];
  #   };
  # };

  # Customize Pi system prompts per model via the systemp-prompt-modifier
  # extension. Keys are `provider/model-id`; `prepend` and `append` are joined
  # with the model's system prompt. Generated into
  # ~/.pi/agent/system-prompt-modifier.json.
  # dotfiles.pi.systemPromptModifier = {
  #   "ai-engine/preview/Kimi-K2.7-Code" = {
  #     prepend = ''
  #       Always respond in Japanese.
  #     '';
  #     append = ''
  #       Keep answers concise and to the point.
  #     '';
  #   };
  # };

  # dotfiles.opencode.provider = {
  #   "ai-engine" = {
  #     name = "AI Engine";
  #     # NOTE: models / options here fully replace the defaults.
  #     models = {
  #       "model-name" = {
  #         name = "Model Name";
  #         # Custom variants for the model. Each variant name maps to a set of
  #         # provider-specific options (e.g., reasoningEffort, textVerbosity,
  #         # thinking, budgetTokens). Set a variant to { disabled = true; } to
  #         # disable a built-in variant.
  #         variants = {
  #           no-think = {
  #             chat_template_kwargs = { reasoning_effort = "no_think"; };
  #           };
  #           low = {
  #             chat_template_kwargs = { reasoning_effort = "low"; };
  #           };
  #           high = {
  #             chat_template_kwargs = { reasoning_effort = "high"; };
  #           };
  #         };
  #         # Model-level provider options (e.g., thinking budget).
  #         options = {
  #           thinking = { type = "enabled"; budgetTokens = 16000; };
  #         };
  #       };
  #     };
  #     options = {
  #       baseURL = "https://api.example.com/v1";
  #       apiKey = "{env:API_KEY}";
  #     };
  #   };
  # };
  # dotfiles.opencode.enabledProviders = [ "test" ];
  # dotfiles.opencode.disabledProviders = [ "test" ];
  # dotfiles.opencode.plugin = [
  #   "opencode-helicone-session"
  #   "opencode-helicone-session@2.1.0"
  #   "@my-org/custom-plugin@next"
  #   "./plugins/my-plugin.ts"
  #   "file:///absolute/path/plugin.js"
  #   [ "opencode-bar" { key = "value"; } ]
  # ];
}

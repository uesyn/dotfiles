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

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

  # nono sandbox profile (fixed name `agents`). `wrap` commands get a shell
  # alias that runs `nono run --profile agents -s --allow-cwd -- <command>`;
  # the OpenCode and Pi modules add themselves to `wrap`.
  # dotfiles.nono.aliasPrefix = "";
  # dotfiles.nono.wrap = [ "opencode" "pi" ];

  # Inside the nono sandbox, `gh` uses a read-only allowlist
  # (`home-manager/nono/commands/gh.nix`): only the listed subcommands run and
  # everything else — including help for denied commands — is denied. `git`
  # defaults to allow with a small remote-operation deny list
  # (`home-manager/nono/commands/git.nix`), so local work runs freely. Flags
  # belong after the subcommand path (`gh repo list -R owner/repo`,
  # `git log --oneline`); `gh --version`/`--help` and read-only git commands
  # work. These are guardrails: each command is a function of `pkgs`, and
  # replacing one needs `lib.mkForce` on the whole command (a plain definition
  # would shallow-merge and break it). Add a new sandbox under a new key.
  # dotfiles.nono.commandPolicies.commands.git = lib.mkForce (pkgs: { ... });
  # dotfiles.nono.commandPolicies.commands.foo = pkgs: { executable = "${pkgs.foo}/bin/foo"; ... };

  # Paths merged into the generated nono profile. The core policy is kept;
  # these options only append, so the profile can be widened/tightened per
  # machine. The option names mirror nono's JSON schema:
  #   dotfiles.nono.filesystem.read             -> filesystem.read
  #   dotfiles.nono.filesystem.readFile         -> filesystem.read_file
  #   dotfiles.nono.filesystem.allow            -> filesystem.allow
  #   dotfiles.nono.filesystem.allowFile        -> filesystem.allow_file
  #   dotfiles.nono.filesystem.unixSocket       -> filesystem.unix_socket
  #   dotfiles.nono.filesystem.deny             -> filesystem.deny
  #   dotfiles.nono.filesystem.bypassProtection -> filesystem.bypass_protection
  #   dotfiles.nono.commandPolicies.executableDirs
  #                                             -> command_policies.executable_dirs
  #   dotfiles.nono.commandPolicies.commands    -> command_policies.commands
  #                                                (each value is `pkgs: {...}`)
  # `deny` paths must not sit below an allowed parent on Linux or nono refuses
  # to start.
  # dotfiles.nono.filesystem.read = [ "~/.config/foo" ];
  # dotfiles.nono.filesystem.readFile = [ "~/.foo.token" ];
  # dotfiles.nono.filesystem.allow = [ "~/work" ];
  # dotfiles.nono.filesystem.allowFile = [ "~/.foo.rc" ];
  # dotfiles.nono.filesystem.unixSocket = [ "/run/user/1000/bus" ];
  # dotfiles.nono.filesystem.deny = [ "~/.ssh2" ];

  # Stable runtime prefix for the Nix-managed GCC, always enabled on Linux.
  # `gcc` / `cc` / `g++` / `c++` are wrappers around `pkgs.gcc-unwrapped` whose
  # output references `~/.local/nix-runtime` instead of `/nix/store/<hash>` paths,
  # so generated ELF files survive Nix GC and toolchain updates. This replaces
  # `pkgs.gcc` in `home.packages`.
  # dotfiles.buildEssential.libraries = [ pkgs.zlib pkgs.openssl ];

  # mise-managed global tools (written to `~/.config/mise/config.toml`).
  # The `go` and `kubernetes` modules contribute their defaults, so a plain
  # definition here overrides them without `lib.mkForce`.
  # `home-manager switch` runs `mise install` for them.
  # dotfiles.mise.tools = {
  #   node = "lts";
  #   python = [ "3.12" "3.11" ];
  # };

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

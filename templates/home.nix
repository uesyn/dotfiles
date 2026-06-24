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

  # dotfiles.opencode.provider = {
  #   "ai-engine" = {
  #     name = "AI Engine";
  #     # NOTE: models / options here fully replace the defaults.
  #     models = {
  #       "model-name" = {
  #         name = "Model Name";
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
  # dotfiles.opencode.plugins = [ "plugin-name" ];
}

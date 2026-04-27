{ ... }:
{
  # home.username = "username";
  # home.homeDirectory = "/home/username";

  # dotfiles.go.private = [];

  # dotfiles.git.user = "username";
  # dotfiles.git.email = "email@example.com";

  # dotfiles.git-credential-oauth.device = false;
  # dotfiles.git-credential-oauth.ghHosts = [];

  # dotfiles.fence.allowedDomains = [ "example.com" ];
  # dotfiles.fence.allowedUnixSockets = [ "/var/run/docker.sock" ];
  # dotfiles.fence.deniedCommands = [ "rm" "dd" ];

  # dotfiles.opencode.provider = {
  #   "ai-engine" = {
  #     npm = "@ai-sdk/openai-compatible";
  #     name = "AI Engine";
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
}

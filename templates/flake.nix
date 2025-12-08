{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # Independent management of nixpkgs
    # nixpkgs.follows = "dotfiles/nixpkgs"; # Use dotfiles nix package
  };

  outputs =
    { dotfiles, ... }:
    {
      packages = dotfiles.lib.forAllSystems (system: {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = dotfiles.lib.hm {
            inherit system;
            # user = builtins.getEnv "USER";
            # homeDirectory = builtins.getEnv "HOME";
            # modules = [];
            # overlays = [];
            # go = {
            #   private = [];
            # };
            # git = {
            #   user = "uesyn";
            #   email = "17411645+uesyn@users.noreply.github.com";
            # };
            # git-credential-oauth = {
            #   device = false;
            #   ghHosts = [];
            # };
            # crush = {
            #   providers = {
            #     "AI Engine" = {
            #       name = "AI Engine";
            #       "base_url" = "https://api.ai.sakura.ad.jp/v1";
            #       api_key = "$AI_ENGINE_API_KEY";
            #       type = "openai-compat";
            #       models = [
            #         {
            #           name = "Qwen3-Coder-480B-A35B-Instruct-FP8";
            #           id = "Qwen3-Coder-480B-A35B-Instruct-FP8";
            #           "context_window" = 135000;
            #           "default_max_tokens" = 20000;
            #         }
            #         {
            #           name = "Qwen3-Coder-30B-A3B-Instruct";
            #           id = "Qwen3-Coder-30B-A3B-Instruct";
            #           "context_window" = 135000;
            #           "default_max_tokens" = 20000;
            #         }
            #       ];
            #     };
            #   };
            # };
          };
        };
      });
      apps = dotfiles.apps;
      formatter = dotfiles.formatter;
    };
}

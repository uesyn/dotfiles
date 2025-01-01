{
  inputs,
  pkgs,
  git,
  git-credential-oauth,
  ...
}: let
  git-oauth-credential-config = {git_host}: {
    "https://${git_host}" = {
      oauthClientId = "0120e057bd645470c1ed";
      oauthClientSecret = "18867509d956965542b521a529a79bb883344c90";
      oauthRedirectURL = "http://localhost/";
    };
  };
in {
  home.packages = [
    pkgs.ghq
  ];

  home.sessionVariables = {
    GIT_EDITOR = "nvim";
  };

  programs.gh = {
    enable = true;
    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
    };
    gitCredentialHelper.enable = false;
    extensions = [
      pkgs.gh-copilot
      pkgs.gh-dash
      pkgs.gh-poi
      pkgs.gh-s
    ];
  };

  programs.git-credential-oauth = {
    enable = true;
    extraFlags =
      if git-credential-oauth.device
      then ["--device"]
      else [];
  };

  programs.git = {
    enable = true;

    userName = git.user;
    userEmail = git.email;

    ignores = [
      ".direnv"
      ".DS_Store"
      ".envrc"
      ".mise.toml"
      "mise.toml"
      ".shell.nix"
      ".venv"
      "venv"
      ".vim-lsp-settings"
    ];

    includes = [
      {path = "~/.gitconfig.local";}
    ];

    hooks = {
      pre-commit = ./hooks/pre-commit;
      pre-push = ./hooks/pre-push;
    };

    extraConfig = {
      ghq.root = "~/src";

      credential =
        {
          helper = [
            ""
            "cache --timeout=86400"
          ];
        }
        // builtins.foldl' (x: y: x // (git-oauth-credential-config {git_host = y;})) {} git-credential-oauth.ghHosts;

      url = {
        "https://github.com/" = {
          insteadOf = "git@github.com:";
        };
      };

      pull.ff = "only";
      feature.manyFiles = true;
      init.defaultBranch = "main";
      index.skipHash = false;
      rebase.updateRefs = true;
      push.autoSetupRemote = true;
    };
  };
}

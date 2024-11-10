{
  inputs,
  pkgs,
  gitUser,
  gitEmail,
  gitHosts,
  ...
}: let
  git-credential-oauth-wrapper = pkgs.writeShellScriptBin "git-credential-oauth-wrapper" ''
    if [ -n "$REMOTE" ] || [ -n "$SSH_CLIENT" ]; then
      exec ${pkgs.git-credential-oauth}/bin/git-credential-oauth -device "$@"
    else
      exec ${pkgs.git-credential-oauth}/bin/git-credential-oauth "$@"
    fi
  '';

  git-oauth-credential = {
    git_host,
  }: {
    "https://${git_host}" = {
      oauthClientId = "0120e057bd645470c1ed";
      oauthClientSecret = "18867509d956965542b521a529a79bb883344c90";
      oauthRedirectURL = "http://localhost/";
    };
  };
in {
  home.packages = [
    git-credential-oauth-wrapper
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

  programs.git = {
    enable = true;

    userName = gitUser;
    userEmail = gitEmail;

    ignores = [
      ".DS_Store"
      ".vim-lsp-settings"
      "venv"
      ".venv"
      "mise.toml"
      ".mise.toml"
      ".envrc"
      ".direnv"
      ".default.nix"
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

      credential = {
        helper = [
          ""
          "cache --timeout=86400"
          "oauth-wrapper"
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
      } // builtins.foldl' (x: y: x // (git-oauth-credential { git_host = y; })) {} gitHosts;

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

{
  pkgs,
  ...
}@inputs:
let
  git =
    inputs.git or {
      user = "uesyn";
      email = "17411645+uesyn@users.noreply.github.com";
    };
  git-credential-oauth =
    inputs.git-credential-oauth or {
      device = false;
      ghHosts = [ ];
    };
  git-oauth-credential-config =
    { git_host }:
    {
      "https://${git_host}" = {
        oauthClientId = "0120e057bd645470c1ed";
        oauthClientSecret = "18867509d956965542b521a529a79bb883344c90";
        oauthRedirectURL = "http://localhost/";
      };
    };
in
{
  home.packages = [
    pkgs.ghq
    pkgs.gh
    pkgs.gh-copilot
    pkgs.gh-dash
    pkgs.gh-poi
    pkgs.gh-s
  ];

  home.sessionVariables = {
    GIT_EDITOR = "nvim";
  };

  programs.git-credential-oauth = {
    enable = true;
    extraFlags = if git-credential-oauth.device then [ "--device" ] else [ ];
  };

  programs.git = {
    enable = true;

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
      "CRUSH.md"
      ".crush"
    ];

    includes = [
      { path = "~/.gitconfig.local"; }
    ];

    hooks = {
      pre-commit = ./hooks/pre-commit;
      pre-push = ./hooks/pre-push;
    };

    settings = {
      ghq.root = "~/src";

      user = {
        name = git.user;
        email = git.email;
      };

      credential = {
        helper = [
          ""
          "cache --timeout=86400"
        ];
      }
      // builtins.foldl' (
        x: y: x // (git-oauth-credential-config { git_host = y; })
      ) { } git-credential-oauth.ghHosts;

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

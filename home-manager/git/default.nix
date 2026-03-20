{
  pkgs,
  ...
}@inputs:
let
  git-allow = pkgs.writeShellScriptBin "git-allow" (builtins.readFile ./commands/git-allow);
  git-fixup = pkgs.writeShellScriptBin "git-fixup" (builtins.readFile ./commands/git-fixup);
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
      # Use the OAuth client information published at github.com/cli/cli
      # https://github.com/cli/cli/blob/trunk/internal/authflow/flow.go#L20-L25
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

    # commands
    git-allow
    git-fixup
  ];

  home.sessionVariables = {
    GIT_EDITOR = "nvim";
  };

  programs.git-credential-oauth = {
    enable = true;
    extraFlags = if git-credential-oauth.device then [ "--device" ] else [ ];
  };

  programs.git-worktree-switcher.enable = true;

  programs.gh = {
    enable = true;
    extensions = [
      pkgs.gh-dash
      pkgs.gh-poi
      pkgs.gh-s
      # pkgs.gh-enhance
    ];
  };
  programs.gh-dash = {
    enable = true;
    settings = {
      prSections = [
        {
          title = "My Pull Requests";
          filters = "is:open author:@me";
        }
        {
          title = "Review Requests";
          filters = "is:open review-requested:@me";
        }
        {
          title = "Open PRs";
          filters = "is:open";
        }
        {
          title = "All PRs";
          filters = "";
        }
      ];
      issuesSections = [
        {
          title = "Assigned Issues";
          filters = "is:open assignee:@me";
        }
        {
          title = "Open Issues";
          filters = "is:open";
        }
        {
          title = "All Issues";
          filters = "";
        }
      ];
      notificationsSections = [
        {
          title = "All";
          filters = "";
        }
        {
          title = "Created";
          filters = "reason:author";
        }
        {
          title = "Participating";
          filters = "reason:participating";
        }
        {
          title = "Mentioned";
          filters = "reason:mention";
        }
        {
          title = "Review Requested";
          filters = "reason:review-requested";
        }
        {
          title = "Assigned";
          filters = "reason:assign";
        }
        {
          title = "Subscribed";
          filters = "reason:subscribed";
        }
        {
          title = "Team Mentioned";
          filters = "reason:team-mention";
        }
      ];
    };
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

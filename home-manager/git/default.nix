{
  config,
  pkgs,
  lib,
  ...
}:
let
  git-allow = pkgs.writeShellScriptBin "git-allow" (builtins.readFile ./commands/git-allow);
  git-fixup = pkgs.writeShellScriptBin "git-fixup" (builtins.readFile ./commands/git-fixup);
  defaultOAuthCredentials = {
    oauthClientId = "0120e057bd645470c1ed";
    oauthClientSecret = "18867509d956965542b521a529a79bb883344c90";
    oauthRedirectURL = "http://localhost/";
  };
  git-host-config = entry: {
    "https://${entry.host}" = {
      oauthClientId =
        if entry.oauthClientId == null then defaultOAuthCredentials.oauthClientId else entry.oauthClientId;
      oauthClientSecret =
        if entry.oauthClientSecret == null then
          defaultOAuthCredentials.oauthClientSecret
        else
          entry.oauthClientSecret;
      oauthRedirectURL =
        if entry.oauthRedirectURL == null then
          defaultOAuthCredentials.oauthRedirectURL
        else
          entry.oauthRedirectURL;
    };
  };
in
{
  options.dotfiles.git = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "uesyn";
      description = "Git user name";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "17411645+uesyn@users.noreply.github.com";
      description = "Git email address";
    };
  };

  options.dotfiles.git-credential-oauth = {
    device = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use device flow for git-credential-oauth";
    };
    ghHosts = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "GitHub host (e.g. \"github.com\")";
            };
            oauthClientId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                OAuth app client id. When `null` (the default) the bundled
                default credentials are used. Setting this requires
                `oauthClientSecret` to be set as well.
              '';
            };
            oauthClientSecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                OAuth app client secret. When `null` (the default) the bundled
                default credentials are used. Setting this requires
                `oauthClientId` to be set as well.
              '';
            };
            oauthRedirectURL = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                OAuth redirect URL. When `null` (the default) `http://localhost/`
                is used. Useful when running behind a reverse proxy or
                matching a custom OAuth app's registered redirect URL.
              '';
            };
          };
        }
      );
      default = [
        { host = "github.com"; }
      ];
      description = ''
        GitHub hosts for OAuth credential configuration. `github.com` is
        included by default with the bundled OAuth app. Override the
        credentials to use your own OAuth app.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.all (
          entry: (entry.oauthClientId == null) == (entry.oauthClientSecret == null)
        ) config.dotfiles.git-credential-oauth.ghHosts;
        message = ''
          dotfiles.git-credential-oauth.ghHosts: oauthClientId and
          oauthClientSecret must be set together (or both left as null
          to use the bundled default credentials) for each host entry.
        '';
      }
    ];
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
      extraFlags = if config.dotfiles.git-credential-oauth.device then [ "--device" ] else [ ];
    };

    programs.git-worktree-switcher.enable = true;

    programs.gh = {
      enable = true;
      extensions = [
        pkgs.gh-dash
        pkgs.gh-poi
        pkgs.gh-s
      ];
      settings = {
        prompt = "enabled";
        aliases = {
          o = "browse";
          pr = "pr create -w";
          co = "pr checkout";
          pv = "pr view";
        };
      };
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
            filters = "reason:review-request";
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
          name = config.dotfiles.git.user;
          email = config.dotfiles.git.email;
        };

        credential = {
          helper = [
            ""
            "cache --timeout=86400"
          ];
        }
        // builtins.foldl' (
          acc: entry: acc // git-host-config entry
        ) { } config.dotfiles.git-credential-oauth.ghHosts;

        pull.ff = "only";
        feature.manyFiles = true;
        init.defaultBranch = "main";
        index.skipHash = false;
        rebase.updateRefs = true;
        push.autoSetupRemote = true;
      };
    };
  };
}

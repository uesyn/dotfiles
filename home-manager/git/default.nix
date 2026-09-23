{
  config,
  pkgs,
  lib,
  options,
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
  defaultGitIgnores = [
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
    ".code-review-graph/"
  ];
  gitCredentialOauthOptions = {
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
  oauthDevice =
    if options.dotfiles.gitCredentialOauth.device.isDefined then
      config.dotfiles.gitCredentialOauth.device
    else
      config.dotfiles.git-credential-oauth.device;
  oauthHosts =
    if options.dotfiles.gitCredentialOauth.ghHosts.isDefined then
      config.dotfiles.gitCredentialOauth.ghHosts
    else
      config.dotfiles.git-credential-oauth.ghHosts;
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
    ignores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Git ignore patterns appended to the module defaults";
    };
  };

  options.dotfiles.gitCredentialOauth = gitCredentialOauthOptions;
  # Keep the old spelling available while configurations migrate.
  options.dotfiles.git-credential-oauth = gitCredentialOauthOptions;

  config = {
    assertions = [
      {
        assertion = lib.all (
          entry: (entry.oauthClientId == null) == (entry.oauthClientSecret == null)
        ) oauthHosts;
        message = ''
          dotfiles.gitCredentialOauth.ghHosts (or the legacy
          dotfiles.git-credential-oauth.ghHosts): oauthClientId and
          oauthClientSecret must be set together (or both left as null
          to use the bundled default credentials) for each host entry.
        '';
      }
    ];
    # nono: read the git/gh config (git-credential-oauth, gh CLI).
    dotfiles.nono.filesystem.read = [
      "~/.config/git"
      "~/.config/gh"
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
      extraFlags = if oauthDevice then [ "--device" ] else [ ];
    };

    programs.git-worktree-switcher.enable = true;

    programs.gh = {
      enable = true;
      extensions = [
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
    programs.git = {
      enable = true;

      ignores = defaultGitIgnores ++ config.dotfiles.git.ignores;

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
        ) { } oauthHosts;

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

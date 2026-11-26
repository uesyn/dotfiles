{
  config,
  pkgs,
  lib,
  ...
}:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  git-allow = pkgs.writeShellScriptBin "git-allow" (builtins.readFile ./commands/git-allow);
  git-fixup = pkgs.writeShellScriptBin "git-fixup" (builtins.readFile ./commands/git-fixup);
  defaultOAuthCredentials = {
    oauthClientId = "0120e057bd645470c1ed";
    oauthClientSecret = "18867509d956965542b521a529a79bb883344c90";
    oauthRedirectURL = "http://localhost/";
  };
  defaultGitIgnores = [
    ".audit/"
    ".claude/"
    ".direnv"
    ".DS_Store"
    ".envrc"
    ".mise.toml"
    ".pi/"
    "mise.toml"
    ".shell.nix"
    ".venv"
    "venv"
    ".vim-lsp-settings"
    "CRUSH.md"
    ".crush"
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
  oauthDevice = config.dotfiles.gitCredentialOauth.device;
  oauthHosts = config.dotfiles.gitCredentialOauth.ghHosts;
  # home-manager builds the `programs.git.hooks` linkFarm and points
  # `core.hooksPath` at it; the directory is not exposed as an option, so read
  # it back from the ini it lands in.
  gitHooksPath = config.programs.git.iniContent.core.hooksPath;
  mkGitHook =
    name: path:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.bash ]; } ''
      install -m755 ${path} "$out"
      export PATH="${pkgs.bash}/bin:$PATH"
      patchShebangs "$out"
    '';
  gitHooks = {
    pre-commit = mkGitHook "pre-commit" ./hooks/pre-commit;
    pre-push = mkGitHook "pre-push" ./hooks/pre-push;
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
    ignores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Git ignore patterns appended to the module defaults";
    };
    signing = {
      key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Key-file path for `user.signingKey`. A null value leaves signing-key
          configuration to Git's other configuration sources.
        '';
      };
      format = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Value for `gpg.format`, such as `ssh` or `openpgp`. A null value
          leaves the setting unset.
        '';
      };
      enable = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Value for `commit.gpgSign`. A null value leaves the setting unset;
          true enables signing by default and false explicitly disables it.
        '';
      };
    };
  };

  options.dotfiles.gitCredentialOauth = gitCredentialOauthOptions;

  config = {
    assertions = [
      {
        assertion = lib.all (
          entry: (entry.oauthClientId == null) == (entry.oauthClientSecret == null)
        ) oauthHosts;
        message = ''
          dotfiles.gitCredentialOauth.ghHosts: oauthClientId and
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

    # The linkFarm entries point to separate store files. Landlock checks the
    # resolved hook and its shebang interpreter, not just the linkFarm path.
    dotfiles.nono.commandPolicies = {
      executableDirs = lib.optionals isLinux [
        gitHooksPath
        "${pkgs.bash}/bin"
      ];
      gitExecPaths = lib.optionals isLinux (
        map toString (lib.attrValues gitHooks)
        ++ [
          "${pkgs.bash}/bin/bash"
          "${pkgs.openssh}/bin/ssh-keygen"
        ]
      );
    };

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

      hooks = gitHooks;

      settings =
        let
          signing = config.dotfiles.git.signing;
        in
        {
          ghq.root = "~/src";

          user = {
            name = config.dotfiles.git.user;
            email = config.dotfiles.git.email;
          }
          // lib.optionalAttrs (signing.key != null) { signingKey = signing.key; };

          credential = {
            helper = [
              ""
              "cache --timeout=86400"
            ];
          }
          // builtins.foldl' (acc: entry: acc // git-host-config entry) { } oauthHosts;

          pull.ff = "only";
          feature.manyFiles = true;
          init.defaultBranch = "main";
          index.skipHash = false;
          rebase.updateRefs = true;
          push.autoSetupRemote = true;
        }
        // lib.optionalAttrs (signing.format != null) {
          gpg = {
            format = signing.format;
          }
          // lib.optionalAttrs (signing.format == "ssh") {
            ssh.program = "${pkgs.openssh}/bin/ssh-keygen";
          };
        }
        // lib.optionalAttrs (signing.enable != null) {
          commit.gpgSign = signing.enable;
        };
    };
  };
}

{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.nono = {
    profileName = lib.mkOption {
      type = lib.types.str;
      default = "agents";
      description = "nono profile name, written to ~/.config/nono/profiles/<name>.json.";
    };
    aliasPrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Prefix for the generated shell aliases. Defaults to `""`, so the nono
        wrappers take over the plain command names. The fence wrappers stay
        reachable via `dotfiles.fence.aliasPrefix` (default `"fence-"`).
      '';
    };
    wrap = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "opencode"
        "pi"
      ];
      description = ''
        Commands to wrap with nono. Each entry creates a shell alias named
        `<aliasPrefix><command>` in both zsh and bash that runs
        `nono run --profile <profileName> -s --allow-cwd -- <command>`.
      '';
      example = lib.literalExpression ''[ "opencode" "pi" ]'';
    };
    extraReads = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra filesystem paths to grant read-only access inside the sandbox
        (`filesystem.read`). Directories and files are both accepted.
      '';
    };
    extraAllows = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra directories to grant read-write access inside the sandbox
        (`filesystem.allow`). On Linux a path denied below this directory would
        make the sandbox refuse to start, so keep grants scoped to the paths
        that are actually needed.
      '';
    };
    extraAllowFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra single files to grant read-write access inside the sandbox
        (`filesystem.allow_file`). Use this for files whose parent directory
        should stay read-only or hidden (e.g. files reached through a symlink).
      '';
    };
    extraDenys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra paths to deny filesystem access inside the sandbox
        (`filesystem.deny`). Note that on Linux a deny nested below an allowed
        parent is rejected by Landlock, so denied paths must not sit inside the
        read/allow lists above.
      '';
    };
  };

  config =
    let
      nono = config.dotfiles.nono;

      # argv matchers for `command_policies` invocation rules.
      argvPrefix = prefix: { argv.prefix = prefix; };
      argvExact = exact: { argv.exact = exact; };

      # Allowed `gh` subcommands (read-only). Everything else is denied, so an
      # unknown or mutating command fails closed and help of denied commands is
      # not shown. Matching is `argv.prefix`: the subcommand path must come
      # first, so flags go after it (`gh repo list -R owner/repo`); leading
      # flags (`gh -R owner/repo repo list`) are denied. `contains` is not used
      # because another command's arguments could satisfy it
      # (`gh api -f repo list`).
      ghAllowRules = [
        [ "status" ]
        [ "--version" ]
        [ "--help" ]
        [ "-h" ]

        [
          "auth"
          "status"
        ]

        [
          "pr"
          "list"
        ]
        [
          "pr"
          "view"
        ]
        [
          "pr"
          "status"
        ]
        [
          "pr"
          "checks"
        ]
        [
          "pr"
          "diff"
        ]

        [
          "issue"
          "list"
        ]
        [
          "issue"
          "status"
        ]
        [
          "issue"
          "view"
        ]

        [
          "release"
          "list"
        ]
        [
          "release"
          "view"
        ]
        [
          "release"
          "download"
        ]
        [
          "release"
          "verify"
        ]
        [
          "release"
          "verify-asset"
        ]

        [
          "repo"
          "list"
        ]
        [
          "repo"
          "view"
        ]
        [
          "repo"
          "gitignore"
        ]
        [
          "repo"
          "license"
        ]
        [
          "repo"
          "read-dir"
        ]
        [
          "repo"
          "read-file"
        ]
        [
          "repo"
          "autolink"
          "list"
        ]
        [
          "repo"
          "autolink"
          "view"
        ]
        [
          "repo"
          "deploy-key"
          "list"
        ]

        [
          "workflow"
          "list"
        ]
        [
          "workflow"
          "view"
        ]

        [
          "run"
          "list"
        ]
        [
          "run"
          "view"
        ]
        [
          "run"
          "watch"
        ]
        [
          "run"
          "download"
        ]

        [
          "cache"
          "list"
        ]

        [
          "gist"
          "list"
        ]
        [
          "gist"
          "view"
        ]

        [
          "discussion"
          "list"
        ]
        [
          "discussion"
          "view"
        ]

        [
          "project"
          "list"
        ]
        [
          "project"
          "view"
        ]
        [
          "project"
          "field-list"
        ]
        [
          "project"
          "item-list"
        ]

        [
          "label"
          "list"
        ]

        [
          "secret"
          "list"
        ]
        [
          "variable"
          "list"
        ]
        [
          "variable"
          "get"
        ]

        [
          "search"
          "code"
        ]
        [
          "search"
          "commits"
        ]
        [
          "search"
          "issues"
        ]
        [
          "search"
          "prs"
        ]
        [
          "search"
          "repos"
        ]

        [
          "org"
          "list"
        ]

        [
          "ruleset"
          "check"
        ]
        [
          "ruleset"
          "list"
        ]
        [
          "ruleset"
          "view"
        ]

        [
          "attestation"
          "verify"
        ]
        [
          "attestation"
          "download"
        ]
        [
          "attestation"
          "trusted-root"
        ]
      ];

      ghSandbox = {
        fs_read = [
          "."
          "/nix"
          "~/.config/gh"
          "~/.config/git"
        ];
        # CA bundles (Linux / macOS); missing paths are skipped.
        fs_read_file = [
          "/etc/ssl/certs/ca-certificates.crt"
          "/etc/ssl/cert.pem"
        ];
        fs_write = [ "." ];
        network.allow_all = true;
      };
      ghInvocationPolicy = {
        default = "deny";
        allow = map argvPrefix ghAllowRules;
      };

      gitAllowPrefixes = [
        [ "status" ]
        [ "log" ]
        [ "diff" ]
        [ "show" ]
        [ "blame" ]
        [ "describe" ]
        [ "shortlog" ]
        [ "rev-list" ]
        [ "rev-parse" ]
        [ "ls-files" ]
        [ "ls-tree" ]
        [ "cat-file" ]
        [ "diff-tree" ]
        [ "diff-index" ]
        [ "diff-files" ]
        [ "merge-base" ]
        [ "name-rev" ]
        [ "grep" ]
        [ "show-ref" ]
        [ "for-each-ref" ]
        [ "count-objects" ]
        [ "check-ignore" ]
        [ "check-attr" ]
        [ "whatchanged" ]
        [ "verify-commit" ]
        [ "verify-tag" ]
        [ "range-diff" ]
        [ "version" ]
        [ "--version" ]
        [
          "stash"
          "list"
        ]
        [
          "stash"
          "show"
        ]
        [
          "worktree"
          "list"
        ]
        [
          "submodule"
          "status"
        ]
        [
          "submodule"
          "summary"
        ]
        [
          "notes"
          "list"
        ]
        [
          "notes"
          "show"
        ]
        [
          "reflog"
          "show"
        ]
        [
          "reflog"
          "list"
        ]
        [
          "remote"
          "show"
        ]
        [
          "remote"
          "get-url"
        ]
        [
          "config"
          "--get"
        ]
        [
          "config"
          "--get-all"
        ]
        [
          "config"
          "--get-regexp"
        ]
        [
          "config"
          "--get-urlmatch"
        ]
        [
          "config"
          "--list"
        ]
        [
          "config"
          "-l"
        ]
      ];
      gitAllowExact = [
        [ "branch" ]
        [
          "branch"
          "-a"
        ]
        [
          "branch"
          "-r"
        ]
        [
          "branch"
          "-v"
        ]
        [
          "branch"
          "-vv"
        ]
        [
          "branch"
          "--list"
        ]
        [
          "branch"
          "--all"
        ]
        [
          "branch"
          "--remotes"
        ]
        [
          "branch"
          "--verbose"
        ]
        [
          "branch"
          "--show-current"
        ]
        [
          "branch"
          "--merged"
        ]
        [
          "branch"
          "--no-merged"
        ]
        [ "tag" ]
        [
          "tag"
          "-l"
        ]
        [
          "tag"
          "--list"
        ]
        [
          "tag"
          "-n"
        ]
        [
          "tag"
          "-v"
        ]
        [
          "tag"
          "--verify"
        ]
        [
          "tag"
          "--merged"
        ]
        [
          "tag"
          "--no-merged"
        ]
        [ "remote" ]
        [
          "remote"
          "-v"
        ]
        [
          "remote"
          "--verbose"
        ]
        [ "config" ]
        [ "reflog" ]
        [ "notes" ]
      ];
      gitSandbox = {
        fs_read = [
          "."
          "/nix"
          "~/.config/git"
        ];
      };
      gitInvocationPolicy = {
        default = "deny";
        allow = map argvPrefix gitAllowPrefixes ++ map argvExact gitAllowExact;
      };

      wrappedAliases = lib.listToAttrs (
        map (cmd: {
          name = "${nono.aliasPrefix}${cmd}";
          value = "nono run --profile ${nono.profileName} -s --allow-cwd -- ${cmd}";
        }) nono.wrap
      );

      profile = {
        extends = "default";
        workdir = {
          access = "readwrite";
        };
        filesystem = {
          read = [
            "/nix"
            "~/.config/opencode"
            "~/.config/github-copilot"
            "~/.config/gh"
            "~/.config/git"
            "~/.config/mise"
            "~/.config/go"
            "~/.config/nvim"
            "~/.config/nix"
          ]
          ++ nono.extraReads;
          allow = [
            "~/bin"
            "~/pkg"
            "~/src"
            "/tmp"
            "~/.cache"
            "~/.pi"
            "~/.opencode"
            "~/.docker"
            "~/.kube"
            "~/.npm/_cacache"
            "~/.npm/_npx"
            "~/.bun"
            "~/.cargo/registry"
            "~/.cargo/git"
            "~/.zcompdump*"

            "~/.local/share/kubebuilder-envtest"
            "~/.local/share/mise"
            "~/.local/share/opencode"
            "~/.local/share/opentui"
            "~/.local/share/pi"
            "~/.local/share/nvim"

            "~/.local/state/home-manager"
            "~/.local/state/mise"
            "~/.local/state/nix"
            "~/.local/state/nvim"
            "~/.local/state/nvim-baleia-bench"
            "~/.local/state/opencode"
            "~/.local/state/pi"
          ]
          ++ nono.extraAllows;
          allow_file = [
            "/etc/bashrc"
            "~/.cargo/.package-cache"
          ]
          ++ nono.extraAllowFiles;
          deny = [
            "~/.pypirc"
            "~/.cargo/credentials"
            "~/.cargo/credentials.toml"
          ]
          ++ nono.extraDenys;
          bypass_protection = [ "~/.docker" ];
        };
        network = {
          block = false;
        };

        command_policies.commands = {
          gh = {
            executable = "${pkgs.gh}/bin/.gh-wrapped";
            can_use = [ "git" ];
            from.session = {
              sandbox = ghSandbox;
              invocation_policy = ghInvocationPolicy;
            };
          };

          git = {
            from = {
              session = {
                sandbox = gitSandbox;
                invocation_policy = gitInvocationPolicy;
              };
              gh = {
                sandbox = gitSandbox;
                invocation_policy = gitInvocationPolicy;
              };
            };
          };
        };
      };
    in
    {
      home.packages = [
        pkgs.llm-agents.nono
      ];

      programs.zsh.shellAliases = wrappedAliases;
      programs.bash.shellAliases = wrappedAliases;

      xdg.configFile."nono/profiles/${nono.profileName}.json".text = builtins.toJSON profile;
    };
}

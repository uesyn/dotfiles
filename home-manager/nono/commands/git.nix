{
  config,
  lib,
  ...
}:
let
  # Hooks, `git gc` helpers and other multi-call helpers that `git` execs by
  # absolute path (Linux-only; see the option for why this cannot live in
  # `executable_dirs` alone).
  execPaths = config.dotfiles.nono.commandPolicies.gitExecPaths;
  # Local git is free (`default = "allow"`); remote operations other than
  # clone are denied. Only an argv beginning with `clone` gets the networked
  # intercept sandbox below. Leading global flags cannot opt into networking,
  # so `git -c x=y push` stays offline even though it bypasses this deny list.
  gitDenyRules =
    map
      (tokens: {
        argv.prefix = tokens;
        reason = "remote git operations are denied";
      })
      [
        [ "push" ]
        [ "fetch" ]
        [ "pull" ]
        [ "ls-remote" ]
        [
          "remote"
          "add"
        ]
        [
          "remote"
          "remove"
        ]
        [
          "remote"
          "rm"
        ]
        [
          "remote"
          "set-url"
        ]
        [
          "remote"
          "prune"
        ]
        [
          "remote"
          "update"
        ]
        [
          "submodule"
          "add"
        ]
        [
          "submodule"
          "update"
        ]
      ];
  gitSandbox = {
    fs_read = [
      "."
      "@git:toplevel"
      # In a worktree `.git` is a file pointing at the main repository, so the
      # git directory sits outside the checkout.
      "@git:common-dir"
      "/nix/store"
      "~/.config/git"
    ];
    # The global config and the targets of its `include.path`: `git` aborts
    # when an include target exists but cannot be read.
    fs_read_file = [ "@git:config-files" ];
    # Allowed local write commands (commits, rebases, `git stash push`)
    # update the worktree, and from a worktree they write the objects, refs
    # and logs of the main repository's git directory. The main worktree
    # itself stays out of the child sandbox below.
    fs_write = [ "@git:toplevel" "@git:common-dir" ];
  }
  // lib.optionalAttrs (execPaths != [ ]) { exec_paths = execPaths; };
  gitInvocationPolicy = {
    default = "allow";
    deny = gitDenyRules;
  };
  # git's own children (git gc → repack/pack-refs/... and the hooks it execs)
  # get a minimal sandbox: the repository and the global config stay readable,
  # so a hook that shells out to `git` (the dotfiles pre-commit guard reads
  # `git remote -v` and `git branch`) works, while the worktree stays
  # unwritable, so they fail closed if GIT_DIR were ever not forwarded.
  gitChildSandbox = {
    fs_read = [
      "."
      "@git:toplevel"
      "@git:common-dir"
      "/nix/store"
      "~/.config/git"
    ];
    fs_read_file = [ "@git:config-files" ];
  };
  gitChildInvocationPolicy = {
    default = "allow";
    # Do not let recursive git calls opt into the clone intercept sandbox.
    deny = gitDenyRules ++ [
      {
        argv.prefix = [ "clone" ];
        reason = "nested git clone is denied";
      }
    ];
  };
in
{
  dotfiles.nono.commandPolicies.commands.git = pkgs: {
    intercept = [
      {
        match.argv.prefix = [ "clone" ];
        action.type = "passthrough";
        # Overrides (does not extend) the caller edge's sandbox. Avoid
        # @git:toplevel and the other repository tokens because clone may run
        # outside an existing repository.
        sandbox = {
          fs_read = [
            "."
            "/nix/store"
            "~/.config/git"
          ];
          fs_read_file = [
            "/etc/ssl/certs/ca-certificates.crt"
            "/etc/ssl/cert.pem"
          ];
          fs_write = [
            "."
            "/tmp"
          ];
          # git-remote-https and the other PATH-external Git helpers.
          exec_paths = [ "${pkgs.git}/libexec/git-core" ];
          network.allow_all = true;
        };
      }
    ];
    from = {
      session = {
        sandbox = gitSandbox;
        invocation_policy = gitInvocationPolicy;
      };
      gh = {
        sandbox = gitSandbox;
        invocation_policy = gitInvocationPolicy;
      };
      # for git gc, its pack helpers and the hooks it execs
      git = {
        sandbox = gitChildSandbox;
        invocation_policy = gitChildInvocationPolicy;
      };
    };
  };
}

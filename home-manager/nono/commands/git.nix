{ ... }:
let
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
      "/nix/store"
      "~/.config/git"
    ];
    # Allowed local write commands (commits, rebases, `git stash push`)
    # update the worktree. The worktree stays out of the child sandbox below.
    fs_write = [ "@git:toplevel" ];
  };
  gitInvocationPolicy = {
    default = "allow";
    deny = gitDenyRules;
  };
  # git's own children (git gc → repack/pack-refs/...) get a minimal sandbox
  # with no worktree write access, so they fail closed if GIT_DIR were ever
  # not forwarded to the child.
  gitChildSandbox = {
    fs_read = [
      "/nix/store"
      "~/.config/git"
    ];
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
        # @git:toplevel because clone may run outside an existing repository.
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
      # for git gc
      git = {
        sandbox = gitChildSandbox;
        invocation_policy = gitChildInvocationPolicy;
      };
    };
  };
}

{ ... }:
let
  # Local git is free (`default = "allow"`); only remote operations are
  # denied. The git sandboxes are network-blocked, so this list keeps the
  # intent explicit and also covers local (`file://`/path) remotes.
  # Matching starts at the first argument, so a leading global option
  # (`git -c x=y push`) can bypass it; network egress stays blocked at the
  # sandbox level regardless.
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
        [ "clone" ]
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
    deny = gitDenyRules;
  };
in
{
  dotfiles.nono.commandPolicies.commands.git = _: {
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

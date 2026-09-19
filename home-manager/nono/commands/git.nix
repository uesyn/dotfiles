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
      "~/.pi/agent/undo"
    ];
    # pi-undo writes its private gitdir (~/.pi/agent/undo/git/<hash>) and
    # restores files in the worktree. The undo store stays part of the git
    # sandbox (not the pi module) so the whole git policy is one auditable
    # unit; see `commands/default.nix`.
    fs_write = [
      "@git:toplevel"
      "~/.pi/agent/undo"
    ];
  };
  gitInvocationPolicy = {
    default = "allow";
    deny = gitDenyRules;
  };
  # git's own children (git gc → repack/pack-refs/...) only need the
  # private snapshot store. Keeping the worktree out of reach makes them
  # fail closed if GIT_DIR were ever not forwarded to the child.
  gitChildSandbox = {
    fs_read = [
      "/nix/store"
      "~/.config/git"
      "~/.pi/agent/undo"
    ];
    fs_write = [ "~/.pi/agent/undo" ];
  };
  gitChildInvocationPolicy = {
    default = "allow";
    deny = gitDenyRules;
  };
in
{
  dotfiles.nono.commandPolicies.commands.git = _: {
    # git gc spawns git repack/pack-refs/... as `git` children; the tool
    # sandbox strips GIT_* from the child env, so forward the private repo
    # selection to them too.
    export_env = [
      "GIT_DIR"
      "GIT_WORK_TREE"
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

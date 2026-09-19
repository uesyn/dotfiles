# gh/git `command_policies.commands` guardrails. They are kept in the nono
# module (not a tool module) because they are the agent's main guardrails and
# the git sandbox is a single security unit: `~/.pi/agent/undo` is granted in
# the git sandbox (not from the pi module) because pi-undo runs git there, so
# the worktree (`@git:toplevel`) and the private store are allowed together.
{
  imports = [
    ./gh.nix
    ./git.nix
  ];
}

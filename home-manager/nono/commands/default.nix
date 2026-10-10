# gh/git `command_policies.commands` guardrails. They are kept in the nono
# module (not a tool module) because they are the agent's main guardrails and
# the git sandbox is a single security unit.
{
  imports = [
    ./gh.nix
    ./git.nix
  ];
}

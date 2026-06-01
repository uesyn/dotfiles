{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  config = {
    programs.bash = {
      shellAliases = {
        claude = "fence claude";
      };
    };
    home.packages = [
      pkgs.llm-agents.claude-code
    ];
  };
}

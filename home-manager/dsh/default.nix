{ pkgs, ... }:
{
  home.packages = [
    pkgs.llm-agents.dsh
  ];
}

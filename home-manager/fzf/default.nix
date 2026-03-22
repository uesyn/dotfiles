{ ... }:
{
  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 60%"
      "--reverse"
      "--border"
    ];
  };
}

{inputs, ...}: {
  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    defaultOptions = [
      "--height 60%"
      "--reverse"
      "--border"
    ];
  };
}

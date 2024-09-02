{inputs, ...}: {
  programs.fzf = {
    enable = true;
    defaultOptions = [
      "--height 60%"
      "--reverse"
      "--border"
    ];
  };
}

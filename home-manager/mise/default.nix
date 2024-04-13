{inputs, ...}: {
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      settings = {
        python_compile = true;
      };
    };
    settings = {
      experimental = true;
    };
  };
}

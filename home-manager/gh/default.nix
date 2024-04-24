{inputs, ...}: {
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "disabled";
    };
    gitCredentialHelper = {
      enable = false;
    };
  };
}

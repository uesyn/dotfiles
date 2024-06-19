{pkgs, ...}: {
  home.packages = with pkgs; [
    gh-copilot
    gh-dash
    gh-poi
    gh-s
  ];
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

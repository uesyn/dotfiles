{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    mise.enable = true;
    mise.package = pkgs.unstable.mise;
    silent = true;
    config = {
      global = {
        hide_env_diff = true;
      };
    };
  };
}

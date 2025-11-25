{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    krew
    kubectx
    stern
    kind
    kubectl
    kubernetes-helm
    kustomize
  ];

  programs.zsh.initContent = ''
    eval "$(${lib.getExe pkgs.kubectl} completion zsh)"
  '';

  home.sessionVariables = {
    KUBE_EDITOR = "nvim";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.krew/bin"
  ];
}

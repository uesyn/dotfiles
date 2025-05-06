{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    krew
    kubectx
    stern
    kind
    kubectl
    kubernetes-helm
    kustomize
  ];

  home.sessionVariables = {
    KUBE_EDITOR = "nvim";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.krew/bin"
  ];
}

{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    kind
    kubectl
    kubectx
    kubernetes-helm
    kustomize
    stern
  ];

  home.sessionVariables = {
    KUBE_EDITOR = "nvim";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.krew/bin"
  ];
}

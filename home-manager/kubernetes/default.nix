{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    krew
    kubectx
    stern
    unstable.kind
    unstable.kubectl
    unstable.kubernetes-helm
    unstable.kustomize
  ];

  home.sessionVariables = {
    KUBE_EDITOR = "nvim";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.krew/bin"
  ];
}

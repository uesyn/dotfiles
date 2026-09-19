{
  config,
  pkgs,
  lib,
  ...
}:
{
  # nono: kubeconfig/context state plus the kubebuilder envtest assets used by
  # operator tests.
  dotfiles.nono.filesystem.allow = [
    "~/.kube"
    "~/.local/share/kubebuilder-envtest"
  ];

  # kubebuilder (operator scaffolding) is managed by mise. `lib.mkDefault` so
  # a plain user definition overrides this without `mkForce`.
  dotfiles.mise.tools.kubebuilder = lib.mkDefault "4.15.0";

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

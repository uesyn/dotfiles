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

  xdg.configFile = {
    "mise/conf.d/kubectl.toml".text = ''
      [tools]
      kubectl = "1.35.3"
      kubebuilder = "4.13.1"
    '';
  };

  home.activation = {
    miseActivation = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.mise}/bin/mise install
    '';
  };

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

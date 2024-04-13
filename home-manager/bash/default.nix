{inputs, ...}: {
  programs.bash = {
    enable = true;
    shellAliases = {
      k = "kubectl";
      ks = "kubectl -n kube-system";
      kx = "kubectx";
      kn = "kubens";
      venv = "python -m venv .venv";
      z = "zellij attach -c";
      tm = "tmux new-session -ADs main";
    };
    initExtra = ''
      source ${./bashrc}
    '';
  };
}

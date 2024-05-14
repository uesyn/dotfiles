{inputs, ...}: {
  programs.zsh = {
    enable = true;
    shellAliases = {
      k = "kubectl";
      ks = "kubectl -n kube-system";
      kx = "kubectx";
      kn = "kubens";
      ll = "ls --color -l";
      ls = "ls --color";
      venv = "python -m venv .venv";
      z = "zellij attach -c";
      tm = "tmux new-session -ADs main";
    };
    dotDir = ".config/zsh";
    envExtra = ''
      [[ -e "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
    '';
    initExtra = ''
      zmodload zsh/complete
      zmodload zsh/zle

      source ${./exports.zsh}
      source ${./widgets.zsh}
      source ${./bindkeys.zsh}
      source ${./options.zsh}
      source ${./git-prompt.zsh}
      source ${./prompt.zsh}
      source ${./hooks.zsh}

      autoload -Uz ${./functions}/*
    '';
  };
}

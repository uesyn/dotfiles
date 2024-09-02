{
  inputs,
  pkgs,
  ...
}: {
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
      eval $(${pkgs.coreutils}/bin/dircolors -b ${./dircolors})

      source ${./exports.zsh}
      source ${./bindkeys.zsh}
      source ${./options.zsh}
      source ${./hooks.zsh}
      source ${./p10k.zsh}
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

      autoload -Uz ${./functions}/*
    '';
  };
}

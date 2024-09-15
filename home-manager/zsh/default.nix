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
    defaultKeymap = "emacs";
    envExtra = ''
      [[ -e "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
    '';
    initExtra = ''
      source ${./exports.zsh}
      source ${./options.zsh}
      source ${./hooks.zsh}
      source ${./p10k.zsh}
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

      bindkey "^[[Z" reverse-menu-complete
      bindkey "ƒ" forward-word
      bindkey "∫" backward-word
      bindkey "∂" kill-word
      bindkey "˙" backward-kill-word

      autoload -Uz ${./functions}/*
    '';
  };
}

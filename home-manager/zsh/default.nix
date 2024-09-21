{
  inputs,
  pkgs,
  ...
}: let
  zsh-async = builtins.fetchGit {
      url = "https://github.com/mafredri/zsh-async.git";
      ref = "main";
      rev = "ee1d11b68c38dec24c22b1c51a45e8a815a79756";
  };
in {
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
      zmodload zsh/complete
      zmodload zsh/zle

      source ${./options.zsh}
      source ${./hooks.zsh}
      source ${zsh-async}/async.zsh
      source ${./prompt.zsh}

      typeset -Ug path fpath manpath

      path=(
        $path
        /usr/local/sbin
        /usr/local/bin
        /usr/sbin
        /usr/bin
        /sbin
        /bin
      )
      
      # Homebrew
      [[ -f /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
      [[ -f /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

      bindkey "^[[Z" reverse-menu-complete
      bindkey "ƒ" forward-word
      bindkey "∫" backward-word
      bindkey "∂" kill-word
      bindkey "˙" backward-kill-word

      bindkey "^[[Z" reverse-menu-complete
      bindkey "ƒ" forward-word
      bindkey "∫" backward-word
      bindkey "∂" kill-word
      bindkey "˙" backward-kill-word

      autoload -Uz ${./functions}/*
    '';
  };
}

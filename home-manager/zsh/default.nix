{
  lib,
  inputs,
  pkgs,
  config,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      k = "kubectl";
      ks = "kubectl -n kube-system";
      kx = "kubectx";
      ll = "ls --color -l";
      ls = "ls --color";
      venv = "python -m venv .venv";
    };
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    defaultKeymap = "emacs";
    envExtra = ''
      touch "$HOME/.zshenv.local" && source "$HOME/.zshenv.local"
    '';
    profileExtra = ''
      # Homebrew
      [[ -f /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
      [[ -f /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
    '';
    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        zmodload zsh/zle
        autoload -U compinit
        local now=$(date +"%s")
        local updated=''${now}
        if [[ -f ''${ZDOTDIR}/.zcompdump ]]; then
          local updated=$(date -r ''${ZDOTDIR}/.zcompdump +"%s")
        fi
        local threshold=$((60 * 60 * 24))
        if [ $((''${now} - ''${updated})) -gt ''${threshold} ]; then
          compinit
        else
          # if there are new functions can be omitted by giving the option -C.
          compinit -C
        fi
      '')
      (lib.mkOrder 1000 ''
        source ${./hooks.zsh}
        source ${./async.zsh}
        source ${./prompt.zsh}

        typeset -Ug path fpath manpath

        [[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

        path=(
          $path
          /usr/local/sbin
          /usr/local/bin
          /usr/sbin
          /usr/bin
          /sbin
          /bin
        )

        bindkey "^[[Z" reverse-menu-complete
        bindkey "ƒ" forward-word
        bindkey "∫" backward-word
        bindkey "∂" kill-word
        bindkey "˙" backward-kill-word

        source ${pkgs.zsh-history-search-multi-word}/share/zsh/zsh-history-search-multi-word/history-search-multi-word.plugin.zsh
        bindkey "^R" history-search-multi-word

        setopt hist_ignore_dups
        setopt hist_ignore_all_dups
        setopt share_history
        setopt auto_menu
        zstyle ':completion:*:default' menu select=1
        setopt auto_pushd
        setopt pushd_ignore_dups
        setopt complete_in_word
        setopt list_packed
        setopt nolistbeep
        setopt transient_rprompt
        setopt hist_ignore_space
        setopt magic_equal_subst
        setopt always_last_prompt

        # zsh
        export WORDCHARS="?!"
        export HISTFILE=${config.home.homeDirectory}/.zsh_history
        export HISTSIZE=1000000000
        export SAVEHIST=1000000000

        autoload -Uz ${./functions}/*
      '')
    ];
  };
}

{
  inputs,
  pkgs,
  ...
}: let
  pkgs-pinned = inputs.nixpkgs-pinned.legacyPackages.${pkgs.system};
in {
  programs.tmux = {
    enable = true;
    package = pkgs-pinned.tmux;
    prefix = "C-s";

    escapeTime = 0;
    baseIndex = 1;
    mouse = true;
    clock24 = true;
    aggressiveResize = true;
    historyLimit = 50000;
    ## https://gist.github.com/bbqtd/a4ac060d6f6b9ea6fe3aabe735aa9d95
    terminal = "screen-256color";
    shell = "${pkgs.zsh}/bin/zsh";

    keyMode = "vi";
    customPaneNavigationAndResize = true;
    resizeAmount = 5;

    extraConfig = ''
      # general configs
      set -g display-time 4000
      set -g focus-events on
      set -g set-clipboard on
      set -g allow-passthrough on
      set -sg terminal-overrides ",*:RGB"
      set -as terminal-features ",*:clipboard"

      # additional key bindings
      bind-key C-s copy-mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection
      bind c new-window -c "#{pane_current_path}"
      bind % split-window -hc "#{pane_current_path}"
      bind '"' split-window -vc "#{pane_current_path}"

      # Theme
      ## Theme settings
      set -g focus-events on
      set -g renumber-windows on
      set -g status-interval 1

      setw -g automatic-rename on

      set -g status-position top
      set -g status-left-length 150
      set -g status-right-length 150

      ## Color
      set -g @theme-color-fg "#f8f8f2"
      set -g @theme-color-bg "#282a36"
      set -g @theme-color-red "#ff5555"
      set -g @theme-color-green "#50fa7b"
      set -g @theme-color-yellow "#f1fa8c"
      set -g @theme-color-blue "#6272a4"
      set -g @theme-color-purple "#bd93f9"
      set -g @theme-color-aqua "#8be9fd"
      set -g @theme-color-gray "#44475a"
      set -g @theme-color-orange "#ffb86c"

      ## Default style
      set -gF mode-style "fg=#{@theme-color-bg},bg=#{@theme-color-yellow}"

      set -gF message-command-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"
      set -gF message-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"

      set -gF pane-border-style "bg=#{@theme-color-bg}"
      set -gF pane-active-border-style "bg=#{@theme-color-bg}"

      set -gF status-left-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"
      set -gF status-right-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"
      set -gF status-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"

      set -gF window-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"

      setw -gF window-status-bell-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"
      setw -gF window-status-current-style "fg=#{@theme-color-bg},bg=#{@theme-color-fg}"
      setw -gF window-status-style "fg=#{@theme-color-fg},bg=#{@theme-color-bg}"
      setw -g window-status-format " #I:#{b:pane_current_path} "
      setw -g window-status-current-format " #I:#{b:pane_current_path} "

      ## status bar widgets
      set -g @theme-widget-time " %Y/%m/%d %H:%M "
      set -g @theme-widget-session " #S "

      ## status bar
      set -gF status-left "#[fg=#{@theme-color-orange},bg=#{@theme-color-bg},bright]#{@theme-widget-session}#[default]"
      set -gF status-right "#[bg=#{@theme-color-purple},bright]#{@theme-widget-time}#[default]"
    '';
  };
}

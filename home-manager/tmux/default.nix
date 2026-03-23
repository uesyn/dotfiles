{
  pkgs,
  ...
}:
let
  osc52-copy = pkgs.writeScriptBin "osc52-copy" ''
    #!${pkgs.bash}/bin/bash
    # Copy to both tmux buffer and OSC52 (system clipboard)
    tmux load-buffer -
    printf '\\033]52;c;%s\\033\\' "$(cat | base64 -w0)"
  '';
in
{
  home.packages = with pkgs; [
    tmux
    tmuxPlugins.fingers
    osc52-copy
  ];

  home.file = {
    ".config/tmux/tmux.conf".text = ''
      # ========================================
      # Basic Settings
      # ========================================
      set -g default-shell ${pkgs.zsh}/bin/zsh
      set-option -g set-clipboard on
      set -g mouse on
      set -g history-limit 10000
      set -g escape-time 0
      set -g base-index 1
      set -g pane-base-index 1
      set -g renumber-windows on
      set -g mode-keys vi
      set -g default-terminal "tmux-256color"
      set -as terminal-overrides ",xterm*:Tc"
      set -g allow-passthrough on
      set -g status-position top
      set -g window-style 'fg=#f8f8f2,bg=#282a36'
      set -g window-active-style 'fg=#f8f8f2,bg=#282a36'

      # Prefix: Ctrl-s (instead of Ctrl-b)
      unbind C-b
      set -g prefix C-s
      bind C-s send-prefix

      # ========================================
      # Dracula Theme Colors
      # https://draculatheme.com/contribute
      # ========================================
      # Background: #282a36
      # Current Line: #44475a
      # Foreground: #f8f8f2
      # Comment: #6272a4
      # Cyan: #8be9fd
      # Green: #50fa7b
      # Orange: #ffb86c
      # Pink: #ff79c6
      # Purple: #bd93f9
      # Red: #ff5555
      # Yellow: #f1fa8c

      # Pane border
      set -g pane-border-style "fg=#6272a4"
      set -g pane-active-border-style "fg=#bd93f9"
      set -g pane-border-format ""

      # Status bar
      set -g status-style "bg=#282a36,fg=#f8f8f2"
      set -g status-left-length 50
      set -g status-right-length 150

      # Status bar content
      set -g status-left "#[bg=#44475a,fg=#50fa7b,bold] #S #[bg=#282a36,fg=#44475a] "
      set -g status-right "#[bg=#282a36,fg=#6272a4] %Y-%m-%d %H:%M #[bg=#44475a,fg=#8be9fd] #h "

      # Window status
      set -g window-status-style "fg=#6272a4,bg=#282a36"
      set -g window-status-current-style "fg=#282a36,bg=#bd93f9,bold"
      set -g window-status-activity-style "fg=#f1fa8c,bg=#282a36"
      set -g window-status-format " #I:#W "
      set -g window-status-current-format " #I:#W "

      # Message
      set -g message-style "fg=#f8f8f2,bg=#44475a"
      set -g message-command-style "fg=#f8f8f2,bg=#44475a"

      # Mode (copy-mode)
      set -g mode-style "bg=#44475a,fg=#f1fa8c"

      # Clock
      set -g clock-mode-colour "#bd93f9"
      set -g clock-mode-style 24

      # Pane index display
      set -g display-panes-colour "#6272a4"
      set -g display-panes-active-colour "#bd93f9"

      # ========================================
      # Copy/Paste Settings
      # ========================================
      # Paste from tmux buffer only (not system clipboard)
      bind p paste-buffer

      # Copy in copy-mode-vi: tmux buffer + OSC52
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "osc52-copy"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "osc52-copy"

      # ========================================
      # tmux-fingers Settings
      # ========================================
      run-shell ${pkgs.tmuxPlugins.fingers}/share/tmux-plugins/tmux-fingers/tmux-fingers.tmux

      set -g @fingers-key "F"
      set -g @fingers-main-action "osc52-copy"
      set -g @fingers-pattern-0 '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$' # UUID
      set -g @fingers-pattern-1 '(sha256|sha384|sha512)-[A-Za-z0-9\+/]+={0,2}( +[!-~]*)?'
      set -g @fingers-pattern-2 '[0-9a-f]{7,40}' # git hashes

      # ========================================
      # Key Bindings
      # ========================================
      # Enter copy-mode (scroll back)
      bind '[' copy-mode

      # Pane navigation (vi-mode)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Window navigation (1-9)
      bind -r 1 select-window -t :1
      bind -r 2 select-window -t :2
      bind -r 3 select-window -t :3
      bind -r 4 select-window -t :4
      bind -r 5 select-window -t :5
      bind -r 6 select-window -t :6
      bind -r 7 select-window -t :7
      bind -r 8 select-window -t :8
      bind -r 9 select-window -t :9

      # Window operations
      bind c new-window -c "#{pane_current_path}"
      bind x kill-pane
      bind & kill-window

      # Pane splitting
      bind "\"" split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

      # Zoom pane
      bind z resize-pane -Z

      # Search
      bind / copy-mode \; send-keys "/"
      bind ? copy-mode \; send-keys "?"

      # Rename window
      bind , command-prompt -I "#W" "rename-window '%%'"

      # Detach
      bind d send-keys "detach" C-m

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # ========================================
      # Performance tuning for tmux-thumbs
      # ========================================
      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence on
    '';
  };
}

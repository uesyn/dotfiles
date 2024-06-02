{
  inputs,
  pkgs,
  ...
}: let
  # To update rev, ref https://releases.nixos.org/nixpkgs/nixpkgs-24.11pre631646.e2dd4e18cc1c/git-revision
  nixpkgs-pinned = builtins.getFlake "github:NixOS/nixpkgs/e2dd4e18cc1c7314e24154331bae07df76eb582f";
  pkgs-pinned = nixpkgs-pinned.legacyPackages.${pkgs.system};
in {
  home.packages = [
    pkgs-pinned.tmux
  ];

  home.file = {
    ".config/tmux/tmux.conf".text = ''
      # dracula
      set -g @dracula-plugins "cpu-usage gpu-usage ram-usage"
      set -g @dracula-show-powerline true
      set -g @dracula-refresh-rate 10
      set -g @dracula-show-ssh-session-port true

      run-shell ${pkgs-pinned.tmuxPlugins.dracula}/share/tmux-plugins/dracula/dracula.tmux

      # general configs
      set -g display-time 4000
      set -g status-interval 5
      set -g focus-events on
      set -g renumber-windows on
      set -g set-clipboard on
      set -g allow-passthrough on
      set -g mode-keys   vi
      set -g status-keys emacs
      set  -g base-index      1
      setw -g pane-base-index 1
      set  -g default-terminal "screen-256color"
      set -sg terminal-overrides ",*:RGB"
      set -as terminal-features ",*:clipboard"
      set  -g default-shell "${pkgs.zsh}/bin/zsh"
      set -g status-position top

      unbind C-b
      set -g prefix C-s
      bind -N "Send the prefix key through to the application" C-s send-prefix
      set  -g mouse             on
      setw -g aggressive-resize on
      setw -g clock-mode-style  24
      set  -s escape-time       0
      set  -g history-limit     50000

      bind -N "Select pane to the left of the active pane" h select-pane -L
      bind -N "Select pane below the active pane" j select-pane -D
      bind -N "Select pane above the active pane" k select-pane -U
      bind -N "Select pane to the right of the active pane" l select-pane -R

      bind -r -N "Resize the pane left by 5" H resize-pane -L 5
      bind -r -N "Resize the pane down by 5" J resize-pane -D 5
      bind -r -N "Resize the pane up by 5" K resize-pane -U 5
      bind -r -N "Resize the pane right by 5" L resize-pane -R 5

      bind-key C-s copy-mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection
      bind c new-window -c "#{pane_current_path}"
      bind % split-window -hc "#{pane_current_path}"
      bind '"' split-window -vc "#{pane_current_path}"
    '';
  };
}

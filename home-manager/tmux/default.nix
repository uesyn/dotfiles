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
    plugins = [
      { 
        plugin = pkgs-pinned.tmuxPlugins.dracula;
        extraConfig = ''
          set -g @dracula-plugins "cpu-usage gpu-usage ram-usage"
          set -g @dracula-show-powerline true
          set -g @dracula-refresh-rate 10
          set -g @dracula-show-ssh-session-port true
        '';
      }
    ];
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

      setw -g automatic-rename on

      set -g status-position top
    '';
  };
}

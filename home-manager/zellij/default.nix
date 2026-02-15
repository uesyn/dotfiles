{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    zellij
  ];

  home.file = {
    ".config/zellij/config.kdl".text = ''
      on_force_close "quit"
      default_shell "zsh"
      pane_frames false
      theme "dracula"
      default_mode "normal"
      mouse_mode true
      scroll_buffer_size 10000
      copy_on_select true
      scrollback_editor "nvim"
      mirror_session true
      auto_layout false
      show_startup_tips false

      plugins {
          tab-bar { path "tab-bar"; }
          status-bar { path "status-bar"; }
          strider { path "strider"; }
          compact-bar { path "compact-bar"; }
      }

      themes {
         dracula {
              fg 248 248 242
              bg 40 42 54
              black 0 0 0
              red 255 85 85
              green 80 250 123
              yellow 241 250 140
              blue 98 114 164
              magenta 255 121 198
              cyan 139 233 253
              white 255 255 255
              orange 255 184 108
          }
      }

      ui {
          pane_frames {
              hide_session_name false
          }
      }

      keybinds {
        shared_except "locked" {
            unbind "Ctrl g"
            bind "Ctrl q" { SwitchToMode "Locked"; }
        }
        locked {
            unbind "Ctrl g"
            bind "Ctrl q" { SwitchToMode "Normal"; }
        }
      }
    '';

    ".config/zellij/layouts/simple.kdl".text = ''
      layout {
          pane size=1 borderless=true {
              plugin location="compact-bar"
          }
          pane
      }
    '';
  };
}

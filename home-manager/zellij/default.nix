{
  inputs,
  pkgs,
  ...
}: {
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
      default_layout "compact"

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

      keybinds clear-defaults=true {
          normal {
              bind "Ctrl s" { SwitchToMode "tmux"; }
          }
          "search" {
              bind "Ctrl [" "Enter" "Esc" "Ctrl c" "i" { ScrollToBottom; SwitchToMode "normal"; }
              bind "Ctrl s" { SwitchToMode "tmux"; }
              bind "[" { EditScrollback; ScrollToBottom; SwitchToMode "normal"; }
              bind "/" { SwitchToMode "entersearch"; SearchInput 0; }
              bind "c" { SearchToggleOption "CaseSensitivity"; }
              bind "n" { Search "down"; }
              bind "N" { Search "up"; }
              bind "j" { ScrollDown; }
              bind "k" { ScrollUp; }
              bind "d" { HalfPageScrollDown; }
              bind "u" { HalfPageScrollUp; }
              bind "Ctrl f" { PageScrollDown; }
              bind "Ctrl b" { PageScrollUp; }
              bind "g" { SwitchToMode "scroll"; }
              bind "G" { ScrollToBottom; }
          }
          "scroll" {
              bind "Ctrl [" "Enter" "Esc" "Ctrl c" "i" { ScrollToBottom; SwitchToMode "normal"; }
              bind "g" { ScrollToTop; SwitchToMode "search"; }
          }
          entersearch {
              bind "Ctrl [" "Esc" "Ctrl c" { SwitchToMode "normal"; }
              bind "Enter" { SwitchToMode "search"; }
          }
          renametab {
              bind "Esc" "Ctrl [" "Ctrl c" { UndoRenameTab; SwitchToMode "normal"; }
              bind "Enter" { SwitchToMode "normal"; }
          }
          renamepane {
              bind "Esc" "Ctrl [" "Ctrl c" { UndoRenamePane; SwitchToMode "normal"; }
              bind "Enter" { SwitchToMode "normal"; }
          }
          move {
              bind "Enter" "Esc" "Ctrl [" "Space" "i" { SwitchToMode "normal"; }

              bind "m" { SwitchToMode "tmux"; }
              bind "h" { MovePane "Left"; }
              bind "l" { MovePane "Right"; }
              bind "k" { MovePane "Up"; }
              bind "j" { MovePane "Down"; }
              bind "H" { Resize "Left"; }
              bind "J" { Resize "Down"; }
              bind "K" { Resize "Up"; }
              bind "L" { Resize "Right"; }
              bind "=" { Resize "Increase"; }
              bind "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
          }
          tmux {
              bind "Enter" "Esc" "Ctrl [" "Space" "i" { SwitchToMode "normal"; }

              bind "h" { MoveFocusOrTab "Left"; SwitchToMode "normal"; }
              bind "l" { MoveFocusOrTab "Right"; SwitchToMode "normal"; }
              bind "k" { MoveFocus "Up"; SwitchToMode "normal"; }
              bind "j" { MoveFocus "Down"; SwitchToMode "normal"; }

              bind "1" { GoToTab 1; SwitchToMode "normal"; }
              bind "2" { GoToTab 2; SwitchToMode "normal"; }
              bind "3" { GoToTab 3; SwitchToMode "normal"; }
              bind "4" { GoToTab 4; SwitchToMode "normal"; }
              bind "5" { GoToTab 5; SwitchToMode "normal"; }
              bind "6" { GoToTab 6; SwitchToMode "normal"; }
              bind "7" { GoToTab 7; SwitchToMode "normal"; }
              bind "8" { GoToTab 8; SwitchToMode "normal"; }
              bind "9" { GoToTab 9; SwitchToMode "normal"; }

              bind "c" { NewTab; SwitchToMode "normal"; }
              bind "x" { CloseFocus; SwitchToMode "normal"; }
              bind "n" { NewPane; SwitchToMode "normal"; }
              bind "\"" { NewPane "Down"; SwitchToMode "normal"; }
              bind "%" { NewPane "Right"; SwitchToMode "normal"; }

              bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "normal"; }
              bind "f" { ToggleFloatingPanes; SwitchToMode "normal"; }
              bind "F" { TogglePaneFrames; SwitchToMode "normal"; }

              bind "m" { SwitchToMode "move"; }
              bind "[" { SwitchToMode "search"; }
              bind "/" { SwitchToMode "entersearch"; SearchInput 0; }
              bind "z" { ToggleFocusFullscreen; SwitchToMode "normal"; }
              bind "C" { Clear; SwitchToMode "normal"; }
              bind "," { SwitchToMode "renametab"; TabNameInput 0; }
              bind "<" { SwitchToMode "renamepane"; TabNameInput 0; }
              bind "d" { Detach; }
          }
      }
    '';

    ".config/zellij/layouts/simple.kdl".text = ''
      layout {
          pane size=1 borderless=true {
              plugin location="zellij:compact-bar"
          }
          pane
      }
    '';
  };
}

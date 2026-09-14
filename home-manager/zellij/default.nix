{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    zellij
  ];

  home.file = {
    ".config/zellij/config.kdl".text = ''
      default_shell "zsh"
      pane_frames false
      theme "dracula"
      default_mode "locked"
      mouse_mode true
      scroll_buffer_size 10000
      copy_on_select true
      scrollback_editor "nvim"
      mirror_session true
      auto_layout false
      show_startup_tips false

      plugins {
          tab-bar location="zellij:tab-bar"
          status-bar location="zellij:status-bar"
          strider location="zellij:strider"
          compact-bar location="zellij:compact-bar"
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

      keybinds clear-defaults=true {
          normal {
              bind "[" { EditScrollback { ansi true; }; SwitchToMode "Locked"; }
              bind "z" { ToggleFocusFullscreen; SwitchToMode "Locked"; }
              bind "f" { ToggleFloatingPanes; SwitchToMode "Locked"; }
              bind "h" { MoveFocusOrTab "Left"; SwitchToMode "Locked"; }
              bind "l" { MoveFocusOrTab "Right"; SwitchToMode "Locked"; }
              bind "j" { MoveFocus "Down"; SwitchToMode "Locked"; }
              bind "k" { MoveFocus "Up"; SwitchToMode "Locked"; }
              bind "x" { CloseFocus; SwitchToMode "Locked"; }
              bind "%" { NewPane; SwitchToMode "Locked"; }
              bind "\"" { NewPane "Down"; SwitchToMode "Locked"; }
              bind "c" { NewTab; SwitchToMode "Locked"; }
              bind "1" { GoToTab 1; SwitchToMode "Locked"; }
              bind "2" { GoToTab 2; SwitchToMode "Locked"; }
              bind "3" { GoToTab 3; SwitchToMode "Locked"; }
              bind "4" { GoToTab 4; SwitchToMode "Locked"; }
              bind "5" { GoToTab 5; SwitchToMode "Locked"; }
              bind "6" { GoToTab 6; SwitchToMode "Locked"; }
              bind "7" { GoToTab 7; SwitchToMode "Locked"; }
              bind "8" { GoToTab 8; SwitchToMode "Locked"; }
              bind "9" { GoToTab 9; SwitchToMode "Locked"; }
              bind "Shift h" { Resize "Increase Left"; }
              bind "Shift j" { Resize "Increase Down"; }
              bind "Shift k" { Resize "Increase Up"; }
              bind "Shift l" { Resize "Increase Right"; }
          }

          locked {
              bind "Ctrl s" { SwitchToMode "Normal"; }
          }

          resize {
              bind "h" "Left" { Resize "Increase Left"; }
              bind "j" "Down" { Resize "Increase Down"; }
              bind "k" "Up" { Resize "Increase Up"; }
              bind "l" "Right" { Resize "Increase Right"; }
              bind "H" { Resize "Decrease Left"; }
              bind "J" { Resize "Decrease Down"; }
              bind "K" { Resize "Decrease Up"; }
              bind "L" { Resize "Decrease Right"; }
          }

          pane {
              bind "p" { SwitchToMode "Normal"; }
              bind "h" { MoveFocus "Left"; }
              bind "l" { MoveFocus "Right"; }
              bind "j" { MoveFocus "Down"; }
              bind "k" { MoveFocus "Up"; }
              bind "s" { NewPane "stacked"; SwitchToMode "Locked"; }
              bind "z" { TogglePaneFrames; SwitchToMode "Locked"; }
              bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "Locked"; }
              bind "r" { SwitchToMode "RenamePane"; PaneNameInput 0; }
              bind "i" { TogglePanePinned; SwitchToMode "Locked"; }
          }

          move {
              bind "m" { SwitchToMode "Normal"; }
              bind "n" "Tab" { MovePane; }
              bind "p" { MovePaneBackwards; }
              bind "h" "Left" { MovePane "Left"; }
              bind "j" "Down" { MovePane "Down"; }
              bind "k" "Up" { MovePane "Up"; }
              bind "l" "Right" { MovePane "Right"; }
          }

          tab {
              bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
              bind "h" "k" { GoToPreviousTab; }
              bind "l" "j" { GoToNextTab; }
              bind "n" { NewTab; SwitchToMode "Locked"; }
              bind "x" { CloseTab; SwitchToMode "Locked"; }
          }

          renametab {
              bind "Ctrl c" "Enter" { SwitchToMode "Locked"; }
              bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
          }

          renamepane {
              bind "Ctrl c" "Enter" { SwitchToMode "Locked"; }
              bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
          }

          session {
              bind "o" { SwitchToMode "Normal"; }
              bind "d" { Detach; }
              bind "]" { FocusHostSession; SwitchToMode "Locked"; }
              bind "[" { FocusGuestSession; SwitchToMode "Locked"; }
              bind "f" { ToggleHostFullscreen; SwitchToMode "Locked"; }
              bind "w" {
                  LaunchOrFocusPlugin "session-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "Locked"
              }
              bind "c" {
                  LaunchOrFocusPlugin "configuration" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "Locked"
              }
              bind "p" {
                  LaunchOrFocusPlugin "plugin-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "Locked"
              }
          }

          shared_except "locked" "renametab" "renamepane" {
              bind "Ctrl s" { SwitchToMode "Locked"; }
              bind "Ctrl q" { Quit; }
          }

          shared_except "renamepane" "renametab" "entersearch" "locked" {
              bind "Esc" { SwitchToMode "Locked"; }
          }

          shared_except "locked" "renametab" "renamepane" {
              bind "Enter" { SwitchToMode "Locked"; }
          }

          shared_except "pane" "locked" "renametab" "renamepane" "entersearch" {
              bind "p" { SwitchToMode "Pane"; }
          }

          shared_except "resize" "locked" "renametab" "renamepane" "entersearch" {
              bind "r" { SwitchToMode "Resize"; }
          }

          shared_except "session" "locked" "renametab" "renamepane" "entersearch" {
              bind "o" { SwitchToMode "Session"; }
          }

          shared_except "tab" "locked" "renametab" "renamepane" "entersearch" {
              bind "t" { SwitchToMode "Tab"; }
          }

          shared_except "move" "locked" "renametab" "renamepane" "entersearch" {
              bind "m" { SwitchToMode "Move"; }
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

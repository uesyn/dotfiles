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
              bind "e" { EditScrollback { ansi true; }; SwitchToMode "Locked"; }
              bind "z" { ToggleFocusFullscreen; SwitchToMode "Locked"; }
              bind "f" { ToggleFloatingPanes; SwitchToMode "Locked"; }
          }
      
          locked {
              bind "Ctrl s" { SwitchToMode "Normal"; }
          }
      
          resize {
              bind "r" { SwitchToMode "Normal"; }
      
              bind "h" "Left" { Resize "Increase Left"; }
              bind "j" "Down" { Resize "Increase Down"; }
              bind "k" "Up" { Resize "Increase Up"; }
              bind "l" "Right" { Resize "Increase Right"; }
      
              bind "H" { Resize "Decrease Left"; }
              bind "J" { Resize "Decrease Down"; }
              bind "K" { Resize "Decrease Up"; }
              bind "L" { Resize "Decrease Right"; }
      
              bind "=" "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
          }
      
          pane {
              bind "p" { SwitchToMode "Normal"; }
      
              bind "h" "Left" { MoveFocus "Left"; }
              bind "l" "Right" { MoveFocus "Right"; }
              bind "j" "Down" { MoveFocus "Down"; }
              bind "k" "Up" { MoveFocus "Up"; }
      
              bind "Tab" { SwitchFocus; }
              bind ";" { FocusLastPane; }
      
              bind "n" { NewPane; SwitchToMode "Locked"; }
              bind "d" { NewPane "Down"; SwitchToMode "Locked"; }
              bind "r" { NewPane "Right"; SwitchToMode "Locked"; }
              bind "s" { NewPane "stacked"; SwitchToMode "Locked"; }
      
              bind "x" { CloseFocus; SwitchToMode "Locked"; }
              bind "z" { TogglePaneFrames; SwitchToMode "Locked"; }
              bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "Locked"; }
              bind "c" { SwitchToMode "RenamePane"; PaneNameInput 0; }
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
              bind "t" { SwitchToMode "Normal"; }
      
              bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
      
              bind "h" "Left" "Up" "k" { GoToPreviousTab; }
              bind "l" "Right" "Down" "j" { GoToNextTab; }
      
              bind "n" { NewTab; SwitchToMode "Locked"; }
              bind "x" { CloseTab; SwitchToMode "Locked"; }
              bind "s" { ToggleActiveSyncTab; SwitchToMode "Locked"; }
      
              bind "b" { BreakPane; SwitchToMode "Locked"; }
              bind "]" { BreakPaneRight; SwitchToMode "Locked"; }
              bind "[" { BreakPaneLeft; SwitchToMode "Locked"; }
      
              bind "1" { GoToTab 1; SwitchToMode "Locked"; }
              bind "2" { GoToTab 2; SwitchToMode "Locked"; }
              bind "3" { GoToTab 3; SwitchToMode "Locked"; }
              bind "4" { GoToTab 4; SwitchToMode "Locked"; }
              bind "5" { GoToTab 5; SwitchToMode "Locked"; }
              bind "6" { GoToTab 6; SwitchToMode "Locked"; }
              bind "7" { GoToTab 7; SwitchToMode "Locked"; }
              bind "8" { GoToTab 8; SwitchToMode "Locked"; }
              bind "9" { GoToTab 9; SwitchToMode "Locked"; }
      
              bind "Tab" { ToggleTab; }
          }
      
          scroll {
              bind "s" { SwitchToMode "Normal"; }
      
              bind "f" { SwitchToMode "EnterSearch"; SearchInput 0; }
      
              bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
      
              bind "j" "Down" { ScrollDown; }
              bind "k" "Up" { ScrollUp; }
      
              bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
              bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
      
              bind "d" { HalfPageScrollDown; }
              bind "u" { HalfPageScrollUp; }
      
              bind "[" { ScrollToPreviousPrompt; }
              bind "]" { ScrollToNextPrompt; }
              bind "m" { SelectCommandAtScrollPosition; }
      
              bind "c" { CopyLastCommandOutput; SwitchToMode "Locked"; }
          }
      
          search {
              bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
      
              bind "j" "Down" { ScrollDown; }
              bind "k" "Up" { ScrollUp; }
      
              bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
              bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
      
              bind "d" { HalfPageScrollDown; }
              bind "u" { HalfPageScrollUp; }
      
              bind "n" { Search "down"; }
              bind "p" { Search "up"; }
      
              bind "c" { SearchToggleOption "CaseSensitivity"; }
              bind "w" { SearchToggleOption "Wrap"; }
              bind "o" { SearchToggleOption "WholeWord"; }
      
              bind "[" { ScrollToPreviousPrompt; }
              bind "]" { ScrollToNextPrompt; }
              bind "m" { SelectCommandAtScrollPosition; }
          }
      
          entersearch {
              bind "Ctrl c" "Esc" { SwitchToMode "Scroll"; }
              bind "Enter" { SwitchToMode "Search"; }
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
      
          shared_among "normal" "locked" {
              bind "Alt n" { NewPane; }
              bind "Alt f" { ToggleFloatingPanes; }
      
              bind "Alt i" { MoveTab "Left"; }
              bind "Alt o" { MoveTab "Right"; }
      
              bind "Alt h" "Alt Left" { MoveFocusOrTab "Left"; }
              bind "Alt l" "Alt Right" { MoveFocusOrTab "Right"; }
              bind "Alt j" "Alt Down" { MoveFocus "Down"; }
              bind "Alt k" "Alt Up" { MoveFocus "Up"; }
      
              bind "Alt =" "Alt +" { Resize "Increase"; }
              bind "Alt -" { Resize "Decrease"; }
      
              bind "Alt [" { PreviousSwapLayout; }
              bind "Alt ]" { NextSwapLayout; }
      
              bind "Alt p" { TogglePaneInGroup; }
              bind "Alt Shift p" { ToggleGroupMarking; }
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
      
          shared_except "scroll" "locked" "renametab" "renamepane" "entersearch" {
              bind "s" { SwitchToMode "Scroll"; }
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

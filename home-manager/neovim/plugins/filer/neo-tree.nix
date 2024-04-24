{ pkgs, ... }: {
  programs.nixvim = {
    keymaps = [
      {
        mode = "n";
        key = "<leader>fo";
        action = ":Neotree action=focus reveal toggle<CR>";
        options.silent = true;
      }
    ];

    plugins.neo-tree = {
      enable = true;
      popupBorderStyle = "solid";
      useDefaultMappings = false;
      filesystem = {
        filteredItems = {
          hideDotfiles = false;
          hideGitignored = false;
        };
      };
      window = {
        position = "float";
        mappings = {
          "<cr>" = "open";
          l = {
            command = "open";
          };
          P = {
            command = "toggle_preview";
            config = {
              use_float = true;
            };
          };
          "<esc>" = {
            command = "revert_preview";
          };
          s = {
            command = "open_vsplit";
          };
          S = {
            command = "open_split";
          };
          h = {
            command = "close_node";
          };
          F = {
            command = "add";
            config = {
              show_path = "absolute";
            };
          };
          K = {
            command = "add_directory";
            config = {
              show_path = "absolute";
            };
          };
          D = "delete";
          R = "rename";
          y = "copy_to_clipboard";
          x = "cut_to_clipboard";
          p = "paste_from_clipboard";
          c = "copy";
          m = {
            command = "move";
            config = {
              show_path = "absolute";
            };
          };
          q = "close_window";
          r = "refresh";
          "?" = "show_help";
        };
      };
    };
  };
}

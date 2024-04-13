{
  programs.nixvim = {
    keymaps = [
      {
        mode = ["n"];
        key = "<C-n>";
        action = "<Cmd>BufferNext<CR>";
      }
      {
        mode = ["n"];
        key = "<C-p>";
        action = "<Cmd>BufferPrevious<CR>";
      }
      {
        mode = ["n"];
        key = "<S-q>";
        action = "<Cmd>BufferClose<CR>";
      }
    ];

    plugins.barbar.enable = true;
  };
}

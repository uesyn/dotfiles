{
  programs.nixvim = {
    keymaps = [
      { mode = ["n" "v"]; key = "<leader>"; action = "<Nop>"; }
      { mode = ["n"]; key = "ZZ"; action = "<Nop>"; }
      { mode = ["n"]; key = "ZQ"; action = "<Nop>"; }
      { mode = ["n"]; key = "ZQ"; action = "<Nop>"; }
      { mode = ["n"]; key = "q"; action = "<Nop>"; }
      { mode = ["n"]; key = "Q"; action = "<Nop>"; }
      { mode = ["n"]; key = "<S-l>"; action = "<C-w>l"; }
      { mode = ["n"]; key = "<S-h>"; action = "<C-w>h"; }
      { mode = ["n"]; key = "<S-k>"; action = "<C-w>k"; }
      { mode = ["n"]; key = "<S-j>"; action = "<C-w>j"; }
      { mode = ["n"]; key = "[LSP]"; action = "<Nop>"; }
      { mode = ["n"]; key = "<Leader>l"; action = "[LSP]"; options = { remap = true; }; }
      { mode = ["n"]; key = "[GIT]"; action = "<Nop>"; }
      { mode = ["n"]; key = "<Leader>g"; action = "[GIT]"; options = { remap = true; }; }
      { mode = ["n"]; key = "[BUFFER]"; action = "<Nop>"; }
      { mode = ["n"]; key = "<Leader>g"; action = "[BUFFER]"; options = { remap = true; }; }
    ];
  };
}

{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      openingh-nvim
    ];
    extraConfigLua = ''
      vim.keymap.set('n', '<Leader>ho', '<Cmd>OpenInGHFile<CR>')
      vim.keymap.set('v', '<Leader>ho', "<Esc><Cmd>'<,'>OpenInGHFile<CR>")
    '';
  };
}

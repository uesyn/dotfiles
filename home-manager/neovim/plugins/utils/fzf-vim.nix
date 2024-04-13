{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      fzf-vim
    ];
    extraConfigLua = ''
      vim.keymap.set('n', '<Leader>fs', ":Rg<space>")
      vim.keymap.set('n', '<Leader>ff', "<Cmd>FZF<CR>")
    '';
  };
}

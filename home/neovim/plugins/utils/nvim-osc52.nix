{ pkgs, ... }:
{
  programs.nixvim = {
     extraPlugins = with pkgs.vimPlugins; [
       nvim-osc52
     ];
     extraConfigLua = ''
       vim.keymap.set('v', '<leader>y', require('osc52').copy_visual)
     '';
  };
}

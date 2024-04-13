{ pkgs, ... }:
{
  programs.nixvim = {
     extraPlugins = with pkgs.vimPlugins; [
       nvim-lsp-notify
     ];
     extraConfigLua = ''
       require('lsp-notify').setup({
         notify = require('notify'),
       })
     '';
  };
}

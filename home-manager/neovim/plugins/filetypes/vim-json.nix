{ pkgs, ... }:
{
  programs.nixvim = {
     extraPlugins = with pkgs.vimPlugins; [
       vim-json
     ];

     extraConfigLua = ''
       vim.g.vim_json_syntax_conceal = 0
     '';
  };
}

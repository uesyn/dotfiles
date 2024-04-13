{ pkgs, ... }:
{
  programs.nixvim = {
     extraPlugins = with pkgs.vimPlugins; [
       vim-markdown
     ];

     extraConfigLua = ''
       vim.g.vim_markdown_folding_disabled = 1
       vim.g.vim_markdown_new_list_item_indent = 0
       vim.g.vim_markdown_auto_insert_bullets = 1
       vim.g.vim_markdown_no_default_key_mappings = 1
     '';
  };
}

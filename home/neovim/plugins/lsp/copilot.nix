{ pkgs, ... }:
{
  programs.nixvim = {
     extraPlugins = with pkgs.vimPlugins; [
       copilot-vim
     ];

     extraConfigLua = ''
       local keymap = vim.keymap.set
       -- https://github.com/orgs/community/discussions/29817#discussioncomment-4217615
       keymap(
         "i",
         "<C-l>",
         'copilot#Accept("<CR>")',
         { silent = true, expr = true, script = true, replace_keycodes = false }
       )
       keymap("i", "<C-j>", "<Plug>(copilot-next)")
       keymap("i", "<C-k>", "<Plug>(copilot-previous)")
       keymap("i", "<C-o>", "<Plug>(copilot-dismiss)")
       keymap("i", "<C-f>", "<Plug>(copilot-suggest)")
     '';
  };
}

{
  pkgs,
  lib,
  ...
}: let
  repo = "ixru/nvim-markdown";
  ref = "master";
  rev = "75639723c1a3a44366f80cff11383baf0799bcb5";

  nvim-markdown = pkgs.vimUtils.buildVimPlugin {
    pname = "${lib.strings.sanitizeDerivationName repo}";
    version = ref;
    src = builtins.fetchGit {
      url = "https://github.com/${repo}.git";
      ref = ref;
      rev = rev;
    };
  };
in {
  programs.nixvim = {
    extraPlugins = [
      nvim-markdown
    ];

    autoGroups = {
      my_nvim_markdown = {
        clear = true;
      };
    };

    autoCmd = [
      {
        event = "FileType";
        pattern = "markdown";
        group = "my_nvim_markdown";
        callback = {
          __raw = ''
            function()
              vim.keymap.set('n', '<Leader>mc', '<Plug>Markdown_Checkbox', { buffer = true })
              vim.keymap.set('n', '<CR>', '<Plug>Markdown_FollowLink', { buffer = true })
              vim.keymap.set('i', '<Tab>', '<Plug>Markdown_Jump', { buffer = true })
              vim.keymap.set('i', '<CR>', '<Plug>Markdown_NewLineBelow', { buffer = true })
            end
          '';
        };
      }
    ];

    globals = {
      vim_markdown_no_default_key_mappings = 1;
      vim_markdown_conceal = 0;
    };
  };
}

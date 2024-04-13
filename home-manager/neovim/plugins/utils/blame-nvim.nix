{
  pkgs,
  lib,
  ...
}: let
  repo = "FabijanZulj/blame.nvim";
  ref = "main";
  rev = "dedbcdce857f708c63f261287ac7491a893912d0";

  blame-nvim = pkgs.vimUtils.buildVimPlugin {
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
      blame-nvim
    ];

    autoGroups = {
      my_blame = {
        clear = true;
      };
    };

    autoCmd = [
      {
        event = "FileType";
        pattern = "blame";
        group = "my_blame";
        callback = {
          __raw = ''
            function()
              vim.bo.buflisted = false
              vim.keymap.set('n', '<S-q>', ':clo<CR>', { buffer = true })
              vim.keymap.set('n', '<C-n>', '<Nop>', { buffer = true })
              vim.keymap.set('n', '<C-p>', '<Nop>', { buffer = true })
            end
          '';
        };
      }
    ];

    extraConfigLua = ''
      require("blame").setup()
      vim.keymap.set('n', '<Leader>gb', '<Cmd>BlameToggle<CR>')
    '';
  };
}

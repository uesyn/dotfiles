{
  programs.nixvim = {
    autoGroups = {
      my_quickfix = {
        clear = true;
      };
    };
    autoCmd = [
      {
        event = "FileType";
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
        group = "my_quickfix";
        pattern = "qf";
      }
    ];
  };
}

{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      nvim-osc52
    ];

    autoGroups = {
      my_nvim_osc52 = {
        clear = true;
      };
    };

    autoCmd = [
      {
        event = "TextYankPost";
        pattern = "*";
        callback = {
          __raw = ''
            function()
              if vim.v.event.operator == 'y' then
                print(vim.v.event.regname)
                require('osc52').copy_register("")
              end
            end
          '';
        };
        group = "my_nvim_osc52";
      }
    ];


    extraConfigLua = ''
      vim.keymap.set('v', '<leader>y', require('osc52').copy_visual)
    '';
  };
}

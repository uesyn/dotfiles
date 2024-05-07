{
  programs.nixvim = {
    files = {
      "ftplugin/go.lua" = {
        opts = {
          shiftwidth = 4;
          tabstop = 4;
          softtabstop = 4;
          expandtab = false;
        };
      };

      "ftplugin/nix.lua" = {
        opts = {
          shiftwidth = 2;
          tabstop = 8;
          softtabstop = 2;
          expandtab = true;
        };
      };

      "ftplugin/json.lua" = {
        opts = {
          shiftwidth = 2;
          tabstop = 8;
          softtabstop = 2;
          expandtab = true;
        };
      };
    };
  };
}

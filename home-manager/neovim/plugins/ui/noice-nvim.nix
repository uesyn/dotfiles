{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      nvim-notify
      nui-nvim
      noice-nvim
    ];

    extraConfigLua = ''
      require("noice").setup({
        views = {
          notify = {
            replace = true,
          },
        },
        routes = {
          {
            filter = { event = "msg_show", kind = "", find = "search_count" },
            opts = { skip = true },
          },
          {
            filter = { event = "msg_show", kind = "", find = "^%d+ fewer lines" },
            opts = { skip = true },
          },
          {
            filter = { event = "msg_show", kind = "", find = "^%d+ more lines?;.*" },
            opts = { skip = true },
          },
          {
            filter = { event = "msg_show", kind = "", find = "\".*\" %d+L, %d+B written" },
            opts = { skip = true },
          },
          {
            filter = { event = "msg_show", kind = "emsg", find = "^E486:.*" },
            opts = { skip = true },
          },
          {
            filter = { event = "msg_show", kind = "", find = "^/.*" },
            opts = { skip = true },
          },
        },
        cmdline = {
          format = {
            rg = { pattern = "^:Rg ", icon = "Rg " },
          },
        },
        lsp = {
          hover = {
            enabled = false,
          },
          signature = {
            enabled = false,
          },
          message = {
            enabled = false,
          },
        },
      })
    '';
  };
}

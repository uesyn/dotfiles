{ pkgs, ... }:
{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      nvim-notify
      nui-nvim
      noice-nvim
    ];

    extraConfigLua = ''
      require("noice").setup({
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

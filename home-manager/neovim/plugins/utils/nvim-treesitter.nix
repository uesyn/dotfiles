{pkgs, ...}: {
  programs.nixvim = {
    extraPackages = with pkgs; [
      tree-sitter
    ];

    extraPlugins = with pkgs.vimPlugins; [
      nvim-treesitter
    ];

    extraConfigLua = ''
      local parser_dir = vim.fn.expand('~/.cache/treesitter/parser')
      vim.opt.runtimepath:append(parser_dir)
      require'nvim-treesitter.configs'.setup {
        ensure_installed = { "markdown", "markdown_inline" },
        sync_install = true,
        auto_install = false,
        parser_install_dir = parser_dir,
      }
    '';
  };
}

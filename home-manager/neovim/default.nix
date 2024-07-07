{
  inputs,
  pkgs,
  ...
}: {
  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      bash
      bash-language-server
      fzf
      gopls
      jdt-language-server
      nil # nix LSP
      nodePackages.typescript-language-server
      pyright
      ripgrep
      rust-analyzer
    ];
    extraLuaPackages = with pkgs; [
      lua51Packages.tiktoken_core # depended by CopilotChat-nvim
    ];
  };
}

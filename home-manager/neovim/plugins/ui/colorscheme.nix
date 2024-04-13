{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      dracula-nvim
    ];
    colorscheme = "dracula";
  };
}

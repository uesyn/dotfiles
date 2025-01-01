{pkgs, ...}: let
  plugins = import ./plugins.nix {
    inherit pkgs;
  };
  nvimRtp = pkgs.stdenv.mkDerivation ({
      name = "nvim-rtp";
      src = ./nvim;

      buildPhase = ''
        mkdir -p $out
        find . -type d | xargs -I{} mkdir -p $out/{}
        for file in $(find . -type f); do
          substituteAll $file $out/$file
        done
      '';
    }
    // plugins);
in {
  xdg.configFile = {
    "nvim" = {
      source = nvimRtp;
    };
  };

  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;

    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      bash
      bash-language-server
      fzf
      # jdt-language-server
      nil # nix LSP
      nodePackages.typescript-language-server
      pyright
      ripgrep
      unstable.gopls
      unstable.rust-analyzer
    ];

    extraLuaPackages = ps: [
      ps.tiktoken_core # depended by CopilotChat-nvim
    ];
  };
}

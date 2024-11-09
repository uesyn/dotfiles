{pkgs, ...}: let
  dotfiles = pkgs.stdenv.mkDerivation ({
      name = "dotfiles";
      src = ../..;
      buildPhase = ''
        mkdir -p $out
        cp flake.* $out/
      '';
    });
in {
  programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
  };

  home.file = {
    ".envrc".text = ''
      use flake ${dotfiles}#devShell
    '';
  };
}

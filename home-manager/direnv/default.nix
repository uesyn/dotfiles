{pkgs, ...}: let
  dotfiles = pkgs.stdenv.mkDerivation ({
      name = "dotfiles";
      src = ../..;
      nativeBuildInputs = with pkgs; [ git ];
      buildPhase = ''
        mkdir -p $out
        cp shell.nix $out/
      '';
    });
in {
  programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
  };

  # TODO: Add command to prepare envrc

  home.file = {
    ".envrc".text = ''
      use nix ${dotfiles}/shell.nix
    '';
  };
}

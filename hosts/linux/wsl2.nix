{pkgs, ...}: {
  wsl.enable = true;
  imports = [
    ./default.nix
  ];
}

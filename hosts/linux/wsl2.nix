{pkgs, ...}: {
  wsl.enable = true;
  imports = [
    ./common.nix
  ];
}

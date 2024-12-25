{pkgs, ...}: {
  wsl.enable = true;
  imports = [
    ./base.nix
  ];
}

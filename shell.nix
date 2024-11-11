{
  pkgs ? import <nixpkgs> {},
  packages ? [],
}:
with pkgs;
  mkShell {
    packages =
      packages
      ++ [
        openssl
        pkg-config
      ];
  }

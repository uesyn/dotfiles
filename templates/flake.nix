{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
    nixpkgs.follows = "dotfiles/nixpkgs";
  };

  outputs = {
    dotfiles,
    nixpkgs,
    ...
  }: let
    packages = import ./packages.nix {
      inherit dotfiles;
      inherit nixpkgs;
    };
  in {
    inherit packages;
    apps = dotfiles.apps;
    formatter = dotfiles.formatter;
  };
}

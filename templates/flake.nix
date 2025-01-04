{
  description = "dotfiles configuration";

  inputs = {
    dotfiles.url = "github:uesyn/dotfiles";
    # nixpkgs.follows = "dotfiles/nixpkgs";
    # nixpkgs-unstable.follows = "dotfiles/nixpkgs-unstable";
  };

  outputs = {dotfiles, ...}: let
    packages = import ./packages.nix {
      inherit dotfiles;
    };
  in {
    inherit packages;
    apps = dotfiles.apps;
    formatter = dotfiles.formatter;
  };
}

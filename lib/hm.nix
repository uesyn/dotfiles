{ nixpkgs, home-manager, nix-ai-tools }:
let
  lib = import ./pkgsForSystem.nix nixpkgs nix-ai-tools;
in
{
  inherit (lib) forAllSystems pkgsForSystem;

  hm =
    {
      system,
      user ? builtins.getEnv "USER",
      homeDirectory ? builtins.getEnv "HOME",
      modules ? [ ],
      overlays ? [ ],
      ...
    }@hmInputs:
    home-manager.lib.homeManagerConfiguration {
      pkgs = lib.pkgsForSystem {
        inherit system;
        inherit overlays;
      };
      modules = [
        {
          home.username = user;
          home.homeDirectory = homeDirectory;
        }
        ../home-manager/default.nix
      ]
      ++ modules;
      extraSpecialArgs = hmInputs;
    };
}

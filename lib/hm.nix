{ nixpkgs, home-manager, nix-ai-tools, forAllSystems }:
let
  pkgsForSystem = import ./pkgsForSystem.nix nixpkgs nix-ai-tools;
in
{
  system,
  user ? builtins.getEnv "USER",
  homeDirectory ? builtins.getEnv "HOME",
  modules ? [ ],
  overlays ? [ ],
  ...
}@hmInputs:
home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsForSystem {
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
}

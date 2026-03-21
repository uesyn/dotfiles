inputs:
let
  inherit (inputs) nixpkgs home-manager nix-ai-tools;
  forAllSystems = import ./forAllSystems.nix nixpkgs;
  pkgsForSystem = import ./pkgsForSystem.nix nixpkgs nix-ai-tools;
  hm = import ./hm.nix { inherit home-manager pkgsForSystem forAllSystems; };
in
{ inherit forAllSystems pkgsForSystem hm; }

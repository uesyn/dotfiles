inputs:
let
  inherit (inputs) nixpkgs nix-ai-tools;
  forAllSystems = import ./forAllSystems.nix nixpkgs;
  pkgsForSystem = import ./pkgsForSystem.nix nixpkgs nix-ai-tools;
in
{
  inherit forAllSystems pkgsForSystem;
}

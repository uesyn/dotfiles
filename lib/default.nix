inputs:
let
  inherit (inputs) nixpkgs llm-agents;
  forAllSystems = import ./forAllSystems.nix nixpkgs;
  pkgsForSystem = import ./pkgsForSystem.nix nixpkgs llm-agents;
in
{
  inherit forAllSystems pkgsForSystem;
}

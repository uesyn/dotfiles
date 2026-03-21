inputs:
let
  inherit (inputs) nixpkgs home-manager nix-ai-tools;
  lib = builtins.removeAttrs inputs ["self" "nix-ai-tools"];
in
lib // import ./pkgsForSystem.nix nixpkgs nix-ai-tools
// import ./hm.nix { inherit nixpkgs home-manager nix-ai-tools; }

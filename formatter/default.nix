{nixpkgs}: let
  supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
in
  forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra)

nixpkgs: nix-ai-tools:
let
  forAllSystems = nixpkgs.lib.genAttrs [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  pkgsForSystem' =
    {
      system,
      overlays ? [ ],
    }:
    import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
      overlays = overlays ++ [
        (final: prev: {
          opencode = nix-ai-tools.packages.${system}.opencode;
        })
      ];
    };
in
{
  inherit forAllSystems;
  pkgsForSystem = pkgsForSystem';
}

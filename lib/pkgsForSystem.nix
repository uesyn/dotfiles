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
          crush = nix-ai-tools.packages.${system}.crush;
          code = nix-ai-tools.packages.${system}.code;
          qwen-code = nix-ai-tools.packages.${system}.qwen-code;
          opencode = nix-ai-tools.packages.${system}.opencode;
          droid = nix-ai-tools.packages.${system}.droid;
        })
      ];
    };
in
{
  inherit forAllSystems;
  pkgsForSystem = pkgsForSystem';
}

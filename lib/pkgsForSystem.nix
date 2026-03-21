nixpkgs: nix-ai-tools:
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
}

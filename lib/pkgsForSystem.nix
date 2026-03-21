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
    nix-ai-tools.overlays.default
  ];
}

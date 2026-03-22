nixpkgs: llm-agents:
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
    llm-agents.overlays.default
  ];
}

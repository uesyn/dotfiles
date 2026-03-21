nixpkgs:
nixpkgs.lib.genAttrs [
  "x86_64-linux"
  "aarch64-linux"
  "aarch64-darwin"
]

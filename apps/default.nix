{nixpkgs}: let
  supportedDarwinSystems = ["x86_64-darwin" "aarch64-darwin"];
  supportedLinuxSystems = ["x86_64-linux" "aarch64-linux"];
  supportedSystems = supportedDarwinSystems ++ supportedLinuxSystems;
  forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  hm = pkgs: {
    type = "app";
    program = "${pkgs.writeShellScriptBin "hm.sh" (builtins.readFile ./hm.sh)}/bin/hm.sh";
  };
  nixos = pkgs: {
    type = "app";
    program = "${pkgs.writeShellScriptBin "nixos.sh" (builtins.readFile ./nixos.sh)}/bin/nixos.sh";
  };
in
  forAllSystems (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    hm = hm pkgs;
    nixos = nixos pkgs;
  })

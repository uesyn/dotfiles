{dotfilesLib}: let
  hm = pkgs: {
    type = "app";
    program = "${pkgs.writeShellScriptBin "hm.sh" (builtins.readFile ./hm.sh)}/bin/hm.sh";
  };
  nixos = pkgs: {
    type = "app";
    program = "${pkgs.writeShellScriptBin "nixos.sh" (builtins.readFile ./nixos.sh)}/bin/nixos.sh";
  };
in
  dotfilesLib.forAllSystems (system: let
    pkgs = dotfilesLib.pkgsForSystem system;
  in {
    hm = hm pkgs;
    nixos = nixos pkgs;
  })

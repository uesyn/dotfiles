{dotfilesLib}: let
  hm = pkgs: {
    type = "app";
    program = "${pkgs.writeShellScriptBin "hm.sh" (builtins.readFile ./hm.sh)}/bin/hm.sh";
  };
in
  dotfilesLib.forAllSystems (system: let
    pkgs = dotfilesLib.pkgsForSystem {inherit system;};
  in {
    hm = hm pkgs;
  })

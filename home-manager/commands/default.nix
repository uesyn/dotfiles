{ pkgs, ... }:
let
  clip = pkgs.writeShellScriptBin "clip" (builtins.readFile ./clip);
in
{
  home.packages = [
    clip
  ];
}

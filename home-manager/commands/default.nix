{
  pkgs,
  ...
}: let
  clip = pkgs.writeShellScriptBin "clip" (builtins.readFile ./clip);
  git-allow = pkgs.writeShellScriptBin "git-allow" (builtins.readFile ./git-allow);
  git-fixup = pkgs.writeShellScriptBin "git-fixup" (builtins.readFile ./git-fixup);
in {
  home.packages = [
    clip
    git-allow
    git-fixup
  ];
}

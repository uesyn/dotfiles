{ pkgs, lib, ... }:
let
  repo = "simeji/winresizer";
  ref = "master";
  rev = "9bd559a03ccec98a458e60c705547119eb5350f3";

  winresizer = pkgs.vimUtils.buildVimPlugin {
    pname = "${lib.strings.sanitizeDerivationName repo}";
    version = ref;
    src = builtins.fetchGit {
      url = "https://github.com/${repo}.git";
      ref = ref;
      rev = rev;
    };
  };
in
{
  programs.nixvim = {
     extraPlugins = [
       winresizer
     ];
     extraConfigLua = ''
       vim.g.winresizer_start_key = "<S-w>"
     '';
  };
}

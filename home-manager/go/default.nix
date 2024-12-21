{
  config,
  pkgs,
  ...
}: {
  programs.go = {
    enable = true;
    goPath = "";
    goBin = "bin";
  };
}

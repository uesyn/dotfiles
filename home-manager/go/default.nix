{
  config,
  pkgs,
  go,
  ...
}: {
  programs.go = {
    enable = true;
    goPath = "";
    goBin = "bin";
    goPrivate = go.private;
  };
}

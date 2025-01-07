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

  home.sessionPath = [
    "${config.home.homeDirectory}/bin"
  ];
}

{
  config,
  pkgs,
  lib,
  go,
  ...
}: {
  home.sessionVariables = {
    GOPATH = "${config.home.homeDirectory}";
    GOBIN = "${config.home.homeDirectory}/bin";
    GOPRIVATE = lib.concatStringsSep "," go.private;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin"
  ];

  home.packages = [
    pkgs.go
    pkgs.gopls
  ];
}

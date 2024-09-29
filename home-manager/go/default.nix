{config, pkgs, ...}: {
  home.packages = [
    pkgs.go
  ];

  home.sessionVariables = {
    GOPATH = "${config.home.homeDirectory}";
    GOBIN = "${config.home.homeDirectory}/bin";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin"
  ];
}

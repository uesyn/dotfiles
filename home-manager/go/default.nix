{config, pkgs, ...}: {
  home.packages = [
    pkgs.go
  ];

  home.sessionVariables = {
    GOPATH = "${config.home.homeDirectory}/.cargo/bin";
    GOBIN = "${config.home.homeDirectory}/bin";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin"
  ];
}

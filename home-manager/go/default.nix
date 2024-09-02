{pkgs, ...}: {
  home.packages = [
    pkgs.go
  ];

  home.sessionVariables = {
    GOPATH = "~";
    GOBIN = "~/bin";
  };

  home.sessionPath = [
    ""
  ];
}

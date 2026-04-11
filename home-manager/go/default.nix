{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.go = {
    private = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Go private module patterns for GOPRIVATE";
    };
  };

  config = {
    home.sessionVariables = {
      GOPATH = "${config.home.homeDirectory}";
      GOBIN = "${config.home.homeDirectory}/bin";
      GOPRIVATE = lib.concatStringsSep "," config.dotfiles.go.private;
    };

    home.sessionPath = [
      "${config.home.homeDirectory}/bin"
    ];

    home.packages = [
      pkgs.go
      pkgs.gopls
    ];

    xdg.configFile = {
      "mise/conf.d/go.toml".text = ''
        [tools]
        go = "1.26.2"
      '';
    };
  };
}

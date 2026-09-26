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
    goplsBuildTags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Build tags passed to gopls via GOPLS_BUILD_TAGS; additional tags can be appended from home.nix";
      example = [ "custom" ];
    };
  };

  config = {
    # List option definitions merge, so tags set in home.nix extend these defaults.
    dotfiles.go.goplsBuildTags =
      [
        "e2e"
        "integration"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "linux" ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "darwin" ];

    home.sessionVariables = {
      GOPATH = "${config.home.homeDirectory}";
      GOBIN = "${config.home.homeDirectory}/bin";
      GOPRIVATE = lib.concatStringsSep "," config.dotfiles.go.private;
      GOPLS_BUILD_TAGS = lib.concatStringsSep "," config.dotfiles.go.goplsBuildTags;
    };

    home.sessionPath = [
      "${config.home.homeDirectory}/bin"
    ];

    # nono: read the Go config (the module cache lives under `~/pkg`, which
    # the nono core already grants write access to).
    dotfiles.nono.filesystem.read = [ "~/.config/go" ];

    # Go is managed by mise instead of nixpkgs: the nono Tool Sandbox only
    # allows executing binaries reachable through PATH (plus its dependency
    # closure), and nixpkgs Go re-execs its helpers from `$GOROOT/pkg/tool` (a
    # PATH-external store path), which fails with `EACCES` (`go tool compile:
    # permission denied`). mise installs under `~/.local/share/mise`, which the
    # nono profile grants write access to, so these execs are allowed.
    # `lib.mkDefault` so a plain user definition overrides this without `mkForce`.
    dotfiles.mise.tools.go = lib.mkDefault "1.26";

    home.packages = [
      pkgs.gopls
    ];
  };
}

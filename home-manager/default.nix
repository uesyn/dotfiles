{
  config,
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in {
  imports = [
    ./bash
    ./commands
    ./dircolors
    ./direnv
    ./fzf
    ./git
    ./go
    ./kubernetes
    ./misc
    ./mise
    ./neovim
    ./node
    ./rust
    ./zellij
    ./zsh
  ];

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  # Please read release note to update this: https://home-manager.dev/manual/unstable/release-notes.xhtml
  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.packages =
    [
      pkgs.autoconf
      pkgs.coreutils-full
      pkgs.curl
      pkgs.diffutils
      pkgs.dig
      pkgs.docker-buildx
      pkgs.docker-client
      pkgs.file
      pkgs.findutils
      pkgs.fzf
      pkgs.gcc
      pkgs.github-mcp-server
      pkgs.glib
      pkgs.gnugrep
      pkgs.gnumake
      pkgs.gnused
      pkgs.gnutar
      pkgs.htop
      pkgs.jq
      pkgs.jsonnet
      pkgs.just
      pkgs.marp-cli
      pkgs.openssh
      pkgs.openssl
      pkgs.pkg-config
      pkgs.procps
      pkgs.pstree
      pkgs.ripgrep
      pkgs.tree
      pkgs.unzip
      pkgs.uv
      pkgs.wget
      pkgs.xz
      pkgs.yq-go
    ]
    ++ lib.optionals isLinux [
      # GNU/Linux packages
      pkgs.iproute2
      pkgs.xdg-utils
    ]
    ++ lib.optionals isDarwin [
      # macOS packages
      pkgs.colima
      pkgs.iproute2mac
      pkgs.docker-credential-helpers
    ];

  home.sessionVariables = {
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    HOMEBREW_NO_AUTO_UPDATE = "1";
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

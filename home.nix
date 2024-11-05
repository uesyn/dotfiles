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
    ./home-manager/bash
    ./home-manager/commands
    ./home-manager/dircolors
    ./home-manager/fzf
    ./home-manager/git
    ./home-manager/go
    ./home-manager/kubernetes
    ./home-manager/mise
    ./home-manager/neovim
    ./home-manager/node
    ./home-manager/rust
    ./home-manager/zellij
    ./home-manager/zsh
  ];

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  # Please read release note to update this: https://home-manager.dev/manual/unstable/release-notes.xhtml
  home.stateVersion = "24.05"; # Please read the comment before changing.

  home.packages = with pkgs;
    [
      coreutils-full
      curl
      diffutils
      dig
      docker-buildx
      docker-client
      file
      findutils
      fzf
      gcc
      gnugrep
      gnumake
      gnused
      gnutar
      htop
      jq
      openssh
      openssl
      pkg-config
      procps
      pstree
      python3
      ripgrep
      tree
      unzip
      wget
      xz
      yq-go
      zsh
    ]
    ++ lib.optionals isLinux [
      # GNU/Linux packages
      iproute2
    ]
    ++ lib.optionals isDarwin [
      # macOS packages
      colima
      darwin.iproute2mac
      docker-credential-helpers
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".config/wezterm/wezterm.lua".source = ./wezterm.lua;
  };

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

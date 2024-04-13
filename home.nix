{ config, pkgs, lib, inputs, username, homeDirectory, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  unsupported = builtins.abort "Unsupported platform";
  overlays = [ inputs.neovim-nightly-overlay.overlay ];
in
{
  nixpkgs.overlays = overlays;

  imports = [
    ./home/neovim
  ];
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = homeDirectory;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    cargo-edit
    coreutils
    curl
    deno
    diffutils
    docker-buildx
    docker-client
    docker-credential-helpers
    findutils
    fzf
    gcc
    ghq
    git
    github-cli
    gnugrep
    gnumake
    gnused
    gnutar
    go
    gopls
    htop
    jq
    kind
    kubectl
    kubectx
    kubernetes-helm
    kustomize
    mise
    nodejs_20
    nodePackages.typescript-language-server
    openssh
    openssl
    procps
    pstree
    ripgrep
    rustup
    stern
    tmux
    tree
    wget
    xz
    yq
    zellij
    zsh
  ] ++ lib.optionals isLinux [
    # GNU/Linux packages
    iproute2
  ] ++ lib.optionals isDarwin [
    # macOS packages
    darwin.iproute2mac
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    ".bashrc".source = bash/bashrc;
    ".bash_profile".source = bash/bash_profile;
    ".zshrc".source = zsh/zshrc;
    ".config/zsh" = {
      source = zsh/zsh;
      recursive = true;
    };
    ".config/mise" = {
      source = ./mise;
      recursive = true;
    };
    ".config/devk" = {
      source = ./devk;
      recursive = true;
    };
    ".config/tmux" = {
      source = ./tmux;
      recursive = true;
    };
    ".config/git" = {
      source = ./git;
      recursive = true;
    };
    ".config/zellij" = {
      source = ./zellij;
      recursive = true;
    };
    ".config/gh" = {
      source = ./gh;
      recursive = true;
    };
    ".config/wezterm/wezterm.lua".source = ./wezterm.lua;
    "opt/bin/clip".source = ./bin/clip;
    "opt/bin/git-allow".source = ./bin/git-allow;
    "opt/bin/git-credential-env".source = ./bin/git-credential-env;
    "opt/bin/git-fixup".source = ./bin/git-fixup;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/uesyn/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

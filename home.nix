{
  config,
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  hmRebuild = pkgs.writeShellScriptBin "update-hm" ''
    case "$1" in
      --help|-h)
        echo "Usage: update-hm [--local|-l]"
        exit 0
        ;;
      --local|-l)
        if [[ ! -f "flake.nix" ]]; then
          echo "flake.nix not found"
          exit 1
        fi
        nix run home-manager -- switch --flake . --impure -b backup
        exit 0
        ;;
      "")
        nix run home-manager -- switch --flake github:uesyn/dotfiles --impure -b backup --refresh
        exit 0
        ;;
      *)
        echo "Invalid option: $1"
        exit 1
        ;;
    esac
  '';
in {
  imports = [
    ./home-manager/commands
    ./home-manager/bash
    ./home-manager/zsh
    ./home-manager/gh
    ./home-manager/git
    ./home-manager/mise
    ./home-manager/tmux
    ./home-manager/zellij
  ];

  home.activation = {
    gitconfigLocal = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pkgs.lib.getExe pkgs.git} config -f ${config.home.homeDirectory}/.gitconfig.local credential.https://github.example.com.oauthClientId 0120e057bd645470c1ed
      run ${pkgs.lib.getExe pkgs.git} config -f ${config.home.homeDirectory}/.gitconfig.local credential.https://github.example.com.oauthClientSecret 18867509d956965542b521a529a79bb883344c90
      run ${pkgs.lib.getExe pkgs.git} config -f ${config.home.homeDirectory}/.gitconfig.local credential.https://github.example.com.oauthRedirectURL http://localhost/
    '';
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  # Please read release note to update this: https://home-manager.dev/manual/unstable/release-notes.xhtml
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages =
    [
      hmRebuild
      pkgs.cargo-edit
      pkgs.cargo-expand
      pkgs.coreutils-full
      pkgs.curl
      pkgs.deno
      pkgs.diffutils
      pkgs.dig
      pkgs.docker-buildx
      pkgs.docker-client
      pkgs.file
      pkgs.findutils
      pkgs.fzf
      pkgs.gcc
      pkgs.ghq
      pkgs.gnugrep
      pkgs.gnumake
      pkgs.gnused
      pkgs.gnutar
      pkgs.go
      pkgs.htop
      pkgs.jq
      pkgs.kind
      pkgs.kubectl
      pkgs.kubectx
      pkgs.kubernetes-helm
      pkgs.kustomize
      pkgs.neovim
      pkgs.nodejs_20
      pkgs.openssh
      pkgs.openssl
      pkgs.pkg-config
      pkgs.procps
      pkgs.pstree
      pkgs.ripgrep
      pkgs.rustup
      pkgs.stern
      pkgs.tree
      pkgs.unzip
      pkgs.wget
      pkgs.xz
      pkgs.yq-go
      pkgs.zsh
    ]
    ++ lib.optionals isLinux [
      # GNU/Linux packages
      pkgs.iproute2
    ]
    ++ lib.optionals isDarwin [
      # macOS packages
      pkgs.colima
      pkgs.darwin.iproute2mac
      pkgs.docker-credential-helpers
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    ".config/wezterm/wezterm.lua".source = ./wezterm.lua;

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
    EDITOR = "nvim";
    KUBE_EDITOR = "nvim";
    GIT_EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

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
    ./home-manager/commands
    ./home-manager/bash
    ./home-manager/zsh
    ./home-manager/git
    ./home-manager/mise
    ./home-manager/zellij
    ./home-manager/node
    ./home-manager/dircolors
    ./home-manager/rust
    ./home-manager/kubernetes
    ./home-manager/fzf
  ];

  home.activation = {
    gitconfigLocal = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pkgs.lib.getExe pkgs.git} config -f ${config.home.homeDirectory}/.gitconfig.local credential.https://github.example.com.oauthClientId 0120e057bd645470c1ed
      run ${pkgs.lib.getExe pkgs.git} config -f ${config.home.homeDirectory}/.gitconfig.local credential.https://github.example.com.oauthClientSecret 18867509d956965542b521a529a79bb883344c90
      run ${pkgs.lib.getExe pkgs.git} config -f ${config.home.homeDirectory}/.gitconfig.local credential.https://github.example.com.oauthRedirectURL http://localhost/
      run ${pkgs.lib.getExe pkgs.gh} config set editor nvim
      run ${pkgs.lib.getExe pkgs.gh} config set prompt disabled
      run ${pkgs.lib.getExe pkgs.gh} config set git_protocol https
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
      neovim
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
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    HOMEBREW_NO_AUTO_UPDATE = "1";
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

self:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  imports = [
    ./autoconf
    ./bash
    ./build-essential
    ./copilot-language-server
    ./dircolors
    ./docker
    ./fence
    ./fzf
    ./git
    ./go
    ./javascript
    ./kubernetes
    ./man
    ./misc
    ./mise
    ./neovim
    ./nono
    ./opencode
    ./openssh
    ./php
    ./pi
    ./pkg-config
    ./python
    ./rust
    ./tmux
    ./zellij
    ./zsh
  ];

  options.dotfiles = {
    username = lib.mkOption {
      type = lib.types.str;
      default = builtins.getEnv "USER";
      description = "username";
    };
    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = builtins.getEnv "HOME";
      description = "home directory";
    };
    overlays = lib.mkOption {
      type = lib.types.listOf (lib.types.functionTo (lib.types.functionTo lib.types.attrs));
      default = [ ];
      description = "Nixpkgs overlays";
    };
    additionalPackages = lib.mkOption {
      type = lib.types.addCheck lib.types.anything builtins.isFunction;
      default = pkgs: [ ];
      description = "additional packages";
    };
  };

  config =
    let
      username = config.dotfiles.username;
      homeDirectory = config.dotfiles.homeDirectory;
      overlays = config.dotfiles.overlays;
      additionalPackages = config.dotfiles.additionalPackages;
    in
    {
      _module.args.inputs = self.inputs;
      nixpkgs = {
        overlays = [
          self.inputs.llm-agents.overlays.shared-nixpkgs
        ]
        ++ overlays;
        config = {
          allowUnfree = true;
        };
      };

      home.username = username;
      home.homeDirectory = homeDirectory;

      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      # Please read release note to update this: https://home-manager.dev/manual/unstable/release-notes.xhtml
      home.stateVersion = "26.05"; # Please read the comment before changing.

      home.packages = [
        pkgs.coreutils-full
        pkgs.curl
        pkgs.diffutils
        pkgs.dig
        pkgs.file
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gnutar
        pkgs.htop
        pkgs.jq
        pkgs.jsonnet
        pkgs.openssl
        pkgs.procps
        pkgs.pstree
        pkgs.ripgrep
        pkgs.socat
        pkgs.tree
        pkgs.typescript-language-server
        pkgs.unzip
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
        pkgs.iproute2mac
      ]
      # `dotfiles.buildEssential` replaces this on Linux with its own
      # wrappers (both provide `bin/gcc` and `bin/cc`).
      ++ lib.optionals (!isLinux) [
        pkgs.gcc
      ]
      ++ (additionalPackages pkgs);

      home.sessionVariables = {
        XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
        XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
        XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
        HOMEBREW_NO_AUTO_UPDATE = "1";
        EDITOR = "nvim";
        LC_CTYPE = "C.UTF-8";
      };

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;
    };
}

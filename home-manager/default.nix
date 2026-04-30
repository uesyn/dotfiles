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
  config = {
    _module.args.inputs = self.inputs;
    nixpkgs = {
      overlays = [
        self.inputs.llm-agents.overlays.default
      ];
      config = {
        allowUnfree = true;
      };
    };

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    # Please read release note to update this: https://home-manager.dev/manual/unstable/release-notes.xhtml
    home.stateVersion = "26.05"; # Please read the comment before changing.

    home.packages = with pkgs; [
      autoconf
      bun
      copilot-language-server
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
      github-mcp-server
      glib
      gnugrep
      gnumake
      gnused
      gnutar
      htop
      jq
      jsonnet
      openssh
      openssl
      phpactor
      pkg-config
      procps
      pstree
      ripgrep
      socat
      tree
      typescript-language-server
      unzip
      uv
      wget
      xz
      yq-go
    ]
    ++ lib.optionals isLinux [
      # GNU/Linux packages
      iproute2
      xdg-utils
    ]
    ++ lib.optionals isDarwin [
      # macOS packages
      colima
      iproute2mac
      docker-credential-helpers
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
  };

  imports = [
    ./bash
    ./dircolors
    ./fence
    ./fzf
    ./git
    ./go
    ./kubernetes
    ./misc
    ./mise
    ./neovim
    ./node
    ./opencode
    ./python
    ./rust
    ./tmux
    ./zellij
    ./zsh
  ];
}

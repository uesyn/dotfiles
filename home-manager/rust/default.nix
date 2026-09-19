{
  config,
  pkgs,
  ...
}:
{
  # nono: rustup/cargo homes must be writable for toolchain installs and the
  # Tool Sandbox exec grant.
  dotfiles.nono.filesystem.allow = [
    "~/.cargo"
    "~/.rustup"
  ];

  home.packages = with pkgs; [
    cargo-cross
    cargo-edit
    cargo-expand
    rustup
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  home.sessionVariables = {
    # https://github.com/cross-rs/cross/issues/260#issuecomment-1140528221
    NIX_STORE = "/nix/store";
  };

  programs.zsh.initContent = ''
    eval "$(${pkgs.rustup}/bin/rustup completions zsh)"
  '';
}

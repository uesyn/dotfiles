{
  config,
  pkgs,
  ...
}: {
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
}

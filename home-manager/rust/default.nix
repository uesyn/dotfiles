{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    rust-bin.stable.latest.default
    unstable.rust-analyzer
    cargo-edit
    cargo-expand
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  home.sessionVariables = {
    # https://github.com/cross-rs/cross/issues/260#issuecomment-1140528221
    NIX_STORE = "/nix/store";
  };
}

# {
#   config,
#   pkgs,
#   ...
# }: {
#   home.packages = [
#     pkgs.rustup
#     pkgs.cargo-cross
#     pkgs.cargo-edit
#     pkgs.cargo-expand
#   ];
#
#   home.sessionPath = [
#     "${config.home.homeDirectory}/.cargo/bin"
#   ];
#
#   home.sessionVariables = {
#     # https://github.com/cross-rs/cross/issues/260#issuecomment-1140528221
#     NIX_STORE = "/nix/store";
#   };
# }

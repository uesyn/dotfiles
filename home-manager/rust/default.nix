{
  config,
  pkgs,
  ...
}: {
  home.packages = [
    pkgs.rustup
    pkgs.cargo-edit
    pkgs.cargo-expand
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}

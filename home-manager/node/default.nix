{
  config,
  pkgs,
  ...
}: {
  home.packages = [
    pkgs.nodejs_20
  ];

  home.file = {
    ".npmrc".text = ''
      prefix=~/.node
    '';
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.node/bin"
  ];
}

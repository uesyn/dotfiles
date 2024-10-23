{
  config,
  pkgs,
  ...
}: {
  home.packages = [
    pkgs.nodejs
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

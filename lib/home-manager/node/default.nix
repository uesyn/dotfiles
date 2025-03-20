{
  config,
  pkgs,
  ...
}: {
  home.file = {
    ".npmrc".text = ''
      prefix=~/.node
    '';
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.node/bin"
  ];
}

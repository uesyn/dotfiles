{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    zellij
  ];

  home.file = {
    ".config/zellij" = {
      source = ./config;
      recursive = true;
    };
  };
}

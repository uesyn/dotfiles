{
  inputs,
  pkgs,
  ...
}: {
  home.file = {
    "opt/bin" = {
      source = ./commands;
      recursive = true;
    };
  };
}
